module Rubydora
  class Node


    def default_attributes
      @default_attributes ||= self.class.default_attributes
    end

    def default_attributes= attributes
      @default_attributes = default_attributes.merge attributes
    end
    

    def attribute_reader attribute_name, profile_field = nil
      return instance_variable_get("@" + attribute_name) if instance_variable_defined? "@" + attribute_name

      val = profile[profile_field]
        
      if val.blank? && self.respond_to?(:default_attributes) && self.default_attributes[attribute_name.to_sym]
        val = Array(self.default_attributes[attribute_name.to_sym])
      end

      if val.is_a? Array
        obj = self
        arr = ArrayWithCallback.new val
        arr.on_change << lambda { |arr, diff| obj.multivalued_attribute_will_change! attribute_name, diff }
        arr
      else
        val
      end
    end

    def content_attribute_reader attribute_name, profile_field = nil
      return instance_variable_get("@" + attribute_name) if instance_variable_defined? "@" + attribute_name

      val = profile.with_content_subject[profile_field]
        
      if val.blank? && self.respond_to?(:default_attributes) && self.default_attributes[attribute_name.to_sym]
        val = Array(self.default_attributes[attribute_name.to_sym])
      end

      if val.is_a? Array
        obj = self
        arr = ArrayWithCallback.new val
        arr.on_change << lambda { |arr, diff| obj.multivalued_attribute_will_change! attribute_name, diff }
        arr
      else
        val
      end
    end

    def attribute_setter attribute_name, val
      check_if_read_only
      current_value = send(attribute_name)

      if current_value.nil? && val.nil?
        return
      end

      if val == current_value 
      elsif current_value.kind_of?(Array) && current_value.length == 1 && val == current_value.first

      else 
        send(attribute_name + "_will_change!")
      end
        
      if val.is_a? Array
        obj = self
        arr = ArrayWithCallback.new val
        arr.on_change << lambda { |arr, diff| obj.multivalued_attribute_will_change! attribute_name, diff }
        instance_variable_set("@" + attribute_name, arr)
      else
        instance_variable_set("@" + attribute_name, val)
      end

    end


    def serialize_changes_to_sparql_update
      deletes = []
      inserts = []

      changes.map do |k, (old_value, new_value)|
        next if ['content', 'ng_xml'].include? k.to_s
        Array(old_value).each do |v|
          if v.is_a? Rubydora::Node
            v = v.uri
          end

          deletes << "<#{uri}> <#{self.class.attributes[k.to_sym].to_s}> \"#{escape_sparql_objects(v)}\" . " if v
        end
        Array(new_value).each do |v|
          if v.is_a? Rubydora::Node
            v = v.uri
          end
          inserts << "<#{uri}> <#{self.class.attributes[k.to_sym].to_s}> \"#{escape_sparql_objects(v)}\" . " if v
        end
      end

      changed_multivalued_attributes.map do |k, diff|
        diff[:-].each do |v|     
          if v.is_a? Rubydora::Node
            v = v.uri
          end  
          deletes << "<#{uri}> <#{self.class.attributes[k.to_sym].to_s}> \"#{escape_sparql_objects(v)}\" . " if v
        end
        diff[:+].each do |v|    
          if v.is_a? Rubydora::Node
            v = v.uri
          end   
          inserts << "<#{uri}> <#{self.class.attributes[k.to_sym].to_s}> \"#{escape_sparql_objects(v)}\" . " if v
        end
      end

      if deletes.empty? and inserts.empty?
        return
      end

      query = ""

      query += "DELETE { #{deletes.join("\n")} }\n" unless deletes.empty?

      query += "INSERT { #{inserts.join("\n")} }\n" unless inserts.empty?

      query += "WHERE { }"

      query

    end



    def escape_sparql_objects v
      case v
      when TrueClass, FalseClass
        v.to_s
      else

      RDF::NTriples::Writer.escape(v)
      end

    end


    def check_if_read_only
      raise "Can't change values on older versions" if @asOfDateTime
    end

    def multivalued_attribute_will_change! attribute_name, diff = {}
      was = changed_multivalued_attributes[attribute_name] ||= {:- => [], :+ => []}


      was[:-] = (was[:-] - diff[:+]) + (diff[:-])
      was[:+] = (was[:+] - diff[:-]) + (diff[:+])

      changed_multivalued_attributes[attribute_name] = was
    end

    def changed_multivalued_attributes
      @changed_multivalued_attributes ||= {}
    end

    def attribute_will_change! *args
      super
    end

  end
end