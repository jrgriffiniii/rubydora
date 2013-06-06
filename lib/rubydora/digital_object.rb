require 'rdf'

module Rubydora

  # This class represents a Fedora object and provides
  # helpers for managing attributes, datastreams, and
  # relationships. 
  #
  # Using the extension framework, implementors may 
  # provide additional functionality to this base 
  # implementation.
  class DigitalObject < Node
    extend ActiveModel::Callbacks
    define_model_callbacks :save, :create, :destroy
    define_model_callbacks :initialize, :only => :after
    include ActiveModel::Dirty
    include Rubydora::AuditTrail

    extend Deprecation

    attr_reader :pid
    


        RELS_EXT = {"annotations"=>"info:fedora/fedora-system:def/relations-external#hasAnnotation",
                "has_metadata"=>"info:fedora/fedora-system:def/relations-external#hasMetadata",
                "description_of"=>"info:fedora/fedora-system:def/relations-external#isDescriptionOf",
                "part_of"=>"info:fedora/fedora-system:def/relations-external#isPartOf",
                "descriptions"=>"info:fedora/fedora-system:def/relations-external#hasDescription",
                "dependent_of"=>"info:fedora/fedora-system:def/relations-external#isDependentOf",
                "constituents"=>"info:fedora/fedora-system:def/relations-external#hasConstituent",
                "parts"=>"info:fedora/fedora-system:def/relations-external#hasPart",
                "memberOfCollection"=>"info:fedora/fedora-system:def/relations-external#isMemberOfCollection",
                "member_of"=>"info:fedora/fedora-system:def/relations-external#isMemberOf",
                "equivalents"=>"info:fedora/fedora-system:def/relations-external#hasEquivalent",
                "derivations"=>"info:fedora/fedora-system:def/relations-external#hasDerivation",
                "derivation_of"=>"info:fedora/fedora-system:def/relations-external#isDerivationOf",
                "subsets"=>"info:fedora/fedora-system:def/relations-external#hasSubset",
                "annotation_of"=>"info:fedora/fedora-system:def/relations-external#isAnnotationOf",
                "metadata_for"=>"info:fedora/fedora-system:def/relations-external#isMetadataFor",
                "dependents"=>"info:fedora/fedora-system:def/relations-external#hasDependent",
                "subset_of"=>"info:fedora/fedora-system:def/relations-external#isSubsetOf",
                "constituent_of"=>"info:fedora/fedora-system:def/relations-external#isConstituentOf",
                "collection_members"=>"info:fedora/fedora-system:def/relations-external#hasCollectionMember",
                "members"=>"info:fedora/fedora-system:def/relations-external#hasMember"}

    # mapping object parameters to profile elements
    OBJ_ATTRIBUTES = RELS_EXT.merge({
      :state => "info:fedora3/state", 
      :ownerId => "http://purl.org/dc/terms/creator", 
      :label => "http://purl.org/dc/terms/title", 
      :logMessage => nil, 
      :createdDate => "info:fedora/fedora-system:def/internal#created",
      :objCreateDate => "info:fedora/fedora-system:def/internal#created",
      :lastModifiedDate => "info:fedora/fedora-system:def/internal#lastModified",
      :objLastModDate => "info:fedora/fedora-system:def/internal#lastModified",
  
      :datastreams => "info:fedora/fedora-system:def/internal#hasChild",
      :models => 'info:fedora/fedora-system:def/internal#mixinTypes'
    })

    OBJ_DEFAULT_ATTRIBUTES = {:state => "A"}


    define_attribute_methods OBJ_ATTRIBUTES.keys
      
    OBJ_ATTRIBUTES.each do |attribute, profile_name|
      class_eval <<-RUBY
      def #{attribute.to_s}
        return attribute_reader("#{attribute}", "#{profile_name}")
      end

      def #{attribute.to_s}= val
        return attribute_setter("#{attribute}", val)
      end
      RUBY
    end

    def state= val
      raise ArgumentError, "Allowed values for state are 'I', 'A' and 'D'. You provided '#{val}'" unless ['I', 'A', 'D'].include?(val)
      state_will_change! unless val == state
      @state = val
    end

    # Find an existing Fedora object
    #
    # @param [String] pid
    # @param [Rubydora::Repository] context
    # @raise [RecordNotFound] if the record is not found in Fedora 
    def self.find pid, repository = nil, options = {}
      obj = self.new pid, repository, options
      if obj.new?
        raise Rubydora::RecordNotFound, "DigitalObject.find called for an object that doesn't exist"
      end

      obj
    end

    # find or initialize a Fedora object
    # @param [String] pid
    # @param [Rubydora::Repository] repository context
    # @param [Hash] options default attribute values (used esp. for creating new datastreams
    def self.find_or_initialize *args
      self.new *args
    end

    # create a new fedora object (see also DigitalObject#save)
    # @param [String] pid
    # @param [Hash] options
    # @param [Rubydora::Repository] context
    def self.create pid, options = {}, repository = nil
      repository ||= Rubydora.repository
      assigned_pid = repository.ingest(options.merge(:pid => pid))

      self.new assigned_pid, repository
    end

    ##
    # Initialize a Rubydora::DigitalObject, which may or
    # may not already exist in the data store.
    #
    # Provides `after_initialize` callback for extensions
    # 
    # @param [String] pid
    # @param [Rubydora::Repository] repository context
    # @param [Hash] options default attribute values (used esp. for creating new datastreams
    def initialize pid, repository = nil, options = {}
      run_callbacks :initialize do
        self.pid = pid
        @repository = repository
        @options = options

        options.each do |key, value|
          send("#{key}=", value)
        end
      end
    end

    ##
    # Return a full uri pid (for use in relations, etc
    def uri
      return pid if pid =~ /.+\/.+/
      if pid =~ /^\//
        repository.base_url + "#{pid}"
      else
        repository.base_url + "/#{pid}"
      end

    end
    alias_method :fqpid, :uri

    # Does this object already exist?
    # @return [Boolean]
    def new?
      self.profile_data.blank?
    end

    def asOfDateTime asOfDateTime = nil
      if asOfDateTime == nil
        return @asOfDateTime
      end

      return self.class.new(pid, @repository, @options.merge(:asOfDateTime => asOfDateTime))
    end

    def asOfDateTime= val
      @asOfDateTime = val
    end

    # Retrieve the object profile as a hash (and cache it)
    # @return [Hash] see Fedora #getObject documentation for keys
    def profile
      return {} if profile_data.blank?

      @profile ||= begin
        Rubydora::Graph.new self.uri, profile_data, OBJ_ATTRIBUTES
      end.freeze
    end

    def profile_data
      @profile_data ||= begin
        repository.object(:pid => pid)
      rescue RestClient::ResourceNotFound => e
        ""
      end
    end

    def object_xml
      repository.object_xml(pid: pid)
    end

    def profile_xml
      profile_data
    end
    deprecation_deprecate :profile_xml

    def versions
      versions_xml = repository.object_versions(:pid => pid)
      versions_xml.gsub! '<fedoraObjectHistory', '<fedoraObjectHistory xmlns="http://www.fedora.info/definitions/1/0/access/"' unless versions_xml =~ /xmlns=/
      doc = Nokogiri::XML(versions_xml)
      doc.xpath('//access:objectChangeDate', {'access' => 'http://www.fedora.info/definitions/1/0/access/' } ).map do |changeDate|
        self.class.new pid, repository, :asOfDateTime => changeDate.text 
      end
    end


    # List of datastreams
    # @return [Array<Rubydora::Datastream>] 
    def datastreams
      @datastreams ||= begin
        h = Hash.new { |h,k| h[k] = datastream_object_for(k) } 

        Array(profile[:datastreams]).map do |datastream|
          # TODO : this is completely wrong! 
          dsid = datastream.split("/").last
          h[dsid] = datastream_object_for dsid, :profile => profile.with_subject(datastream)
        end               

        h
      end
    end
    alias_method :datastream, :datastreams

    # provide an hash-like way to access datastreams 
    def fetch dsid
      datastreams[dsid]
    end
    alias_method :[], :fetch

    # persist the object to Fedora, either as a new object 
    # by modifing the existing object
    #
    # also will save all `:dirty?` datastreams that already exist 
    # new datastreams must be directly saved
    # 
    # @return [Rubydora::DigitalObject] a new copy of this object
    def save
      check_if_read_only
      run_callbacks :save do
        query = serialize_changes_to_sparql_update
        
        if self.new?
          self.pid = repository.ingest :pid => pid
          repository.modify_object :pid => pid, :query => query if query
          @profile = nil #will cause a reload with updated data
          @profile_data = nil
        else                   
          repository.modify_object :pid => pid, :query => query if query
        end
        @changed_attributes.clear

      end

      self.datastreams.select { |dsid, ds| ds.needs_to_be_saved? }.each { |dsid, ds| ds.save }
      self
    end

    # Purge the object from Fedora
    # @return [Rubydora::DigitalObject] `self`
    def delete
      check_if_read_only
      my_pid = pid
      run_callbacks :destroy do
        @datastreams = nil
        @attributes = {}
        @profile = nil
        @profile_xml = nil
        @pid = nil
        @graph = nil
        @models = nil
        nil
      end
      repository.purge_object(:pid => my_pid) ##This can have a meaningful exception, don't put it in the callback
    end

    # repository reference from the digital object
    # @return [Rubydora::Repository]
    def repository
      @repository ||= Rubydora.repository
    end

    def self.default_attributes
      OBJ_DEFAULT_ATTRIBUTES
    end

    def self.attributes
      OBJ_ATTRIBUTES
    end


    protected
    # set the pid of the object
    # @param [String] pid
    # @return [String] the base pid
    def pid= pid=nil
      @pid = pid.gsub('info:fedora/', '') if pid
    end

    # instantiate a datastream object for a dsid
    # @param [String] dsid
    # @return [Datastream]
    def datastream_object_for dsid, options = {}
      options[:asOfDateTime] ||= asOfDateTime if asOfDateTime
      Datastream.new self, dsid, options
    end

  end
end
