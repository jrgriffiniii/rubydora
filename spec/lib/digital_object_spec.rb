require 'spec_helper'

describe Rubydora::DigitalObject do
  before do
    @mock_repository = mock(Rubydora::Repository, :config=>{}, :base_url => "http://repository")
  end
  describe "new" do
    it "should load a DigitalObject instance" do
      Rubydora::DigitalObject.new("pid").should be_a_kind_of(Rubydora::DigitalObject)
    end
  end

  describe "profile" do
    before(:each) do
      @object = Rubydora::DigitalObject.new 'pid', @mock_repository
    end

    it "should convert object profile to a simple hash" do
      @mock_repository.should_receive(:object).with(:pid => 'pid').and_return("
        <http://repository/pid> <info:fedora/fedora-system:def/internal#createdby> \"<anonymous>\" .
")
      h = @object.profile

      h.should have_key("info:fedora/fedora-system:def/internal#createdby")
      h['info:fedora/fedora-system:def/internal#createdby'].should include '<anonymous>'
    end

    it "should be frozen (to prevent modification)" do
      pending "AF mutates the datastream profile :/"
      @mock_repository.should_receive(:object).with(:pid => 'pid').and_return("
        <http://repository/pid> <info:fedora/fedora-system:def/internal#createdby> \"<anonymous>\" .
")
      h = @object.profile
      expect { h['asdf'] = 'asdf' }.to raise_error
    end

    it "should return an empty array for empty profile fields" do
      @mock_repository.should_receive(:object).with(:pid => 'pid').and_return("
        <http://repository/pid> <info:fedora/fedora-system:def/internal#createdby> \"\" .
")
      @object.profile['a'].should be_empty
    end

    it "should throw exceptions that arise" do
      @mock_repository.should_receive(:object).with(:pid => 'pid').and_raise(Net::HTTPBadResponse)
      expect { @object.profile }.to raise_error(Net::HTTPBadResponse)
    end
  end

  describe "new" do
    before(:each) do
      @mock_repository.stub(:object) { raise RestClient::ResourceNotFound }
      @object = Rubydora::DigitalObject.new 'pid', @mock_repository
    end

    it "should be new" do
      @object.new?.should == true
    end

    it "should call ingest on save" do
      @object.stub(:datastreams) { {} }
      @mock_repository.should_receive(:ingest).with(hash_including(:pid => 'pid')).and_return('pid')
      @object.save
    end

    it "should create a new Fedora object with a generated PID if no PID is provided" do 
      object = Rubydora::DigitalObject.new nil, @mock_repository
      @mock_repository.should_receive(:ingest).with(hash_including(:pid => nil)).and_return('pid')
      object.save
      object.pid.should == 'pid'
    end
  end

  describe "create" do
    it "should call the Fedora REST API to create a new object" do
      @mock_repository.should_receive(:ingest).with(instance_of(Hash)).and_return("pid")
      obj = Rubydora::DigitalObject.create "pid", { :a => 1, :b => 2}, @mock_repository
      obj.should be_a_kind_of(Rubydora::DigitalObject)
    end

    it "should return a new object with the Fedora response pid when no pid is provided" do
      @mock_repository.should_receive(:ingest).with(instance_of(Hash)).and_return("pid")
      obj = Rubydora::DigitalObject.create "new", { :a => 1, :b => 2}, @mock_repository
      obj.should be_a_kind_of(Rubydora::DigitalObject)
      obj.pid.should == "pid"
    end
  end

  describe "retreive" do
    before(:each) do
      @object = Rubydora::DigitalObject.new 'pid', @mock_repository
      @object.stub(:new? => false)
      @object.stub(:profile_data => "<http://repository/pid> <info:fedora/fedora-system:def/internal#hasChild> <http://repository/pid/a> .
        <http://repository/pid> <info:fedora/fedora-system:def/internal#hasChild> <http://repository/pid/b> .
        <http://repository/pid> <info:fedora/fedora-system:def/internal#hasChild> <http://repository/pid/c>")
    end

    describe "datastreams" do
      it "should provide a hash populated by the existing datastreams" do

        @object.datastreams.should have_key("a")
        @object.datastreams.should have_key("b")
        @object.datastreams.should have_key("c")
      end

      it "should allow other datastreams to be added" do
        @mock_repository.should_receive(:datastream).with(:pid => 'pid', :dsid => 'z').and_raise(RestClient::ResourceNotFound)

        @object.datastreams.length.should == 3

        ds = @object.datastreams["z"]
        ds.should be_a_kind_of(Rubydora::Datastream)
        ds.new?.should == true

        @object.datastreams.length.should == 4
      end

      it "should let datastreams be accessed via hash notation" do

        @object['a'].should be_a_kind_of(Rubydora::Datastream)
        @object['a'].should == @object.datastreams['a']
      end

      it "should provide a way to override the type of datastream object to use" do
        class MyCustomDatastreamClass < Rubydora::Datastream; end
        object = Rubydora::DigitalObject.new 'pid', @mock_repository
        object.stub(:profile_data)
        object.stub(:datastream_object_for) do |dsid|
          MyCustomDatastreamClass.new(self, dsid)
        end

        object.datastreams['asdf'].should be_a_kind_of(MyCustomDatastreamClass)
      end

      it "should load initial datastream profile data from information in the object graph" do
        @mock_repository.should_not_receive(:datastream)

        @object.stub(:profile_data => "<http://repository/pid> <info:fedora/fedora-system:def/internal#hasChild> <http://repository/pid/a> .
        <http://repository/pid/a> <http://purl.org/dc/terms/title> \"xyz\"")


        @object.datastreams['a'].label.should include "xyz"
      end
      
    end

  end

  describe "update" do

    before(:each) do
      @mock_repository.stub(:object) { <<-eos
        <http://repository/pid> <http://purl.org/dc/terms/title> "label"
      eos
      }

      @object = Rubydora::DigitalObject.new 'pid', @mock_repository
    end

    it "should not say changed if the value is set the same" do
      @object.label = "label"
      @object.should_not be_changed
    end
  end

  describe "retrieve" do

  end

  describe "save" do
    before(:each) do
      @mock_repository.stub(:object) { <<-eos
        <http://repository/pid> <http://purl.org/dc/terms/title> "label"
      eos
      }

      @object = Rubydora::DigitalObject.new 'pid', @mock_repository
    end

    describe "saving an object's datastreams" do

      it "should save a datastream that 'needs to be saved'" do
        mock_ds = mock(:needs_to_be_saved? => true)
        @object.stub(:datastreams) { { :new_ds => mock_ds } }
        mock_ds.should_receive(:save)
        @object.save
      end

      it "should not save a datastream that doesn't need to be saved'" do
        mock_ds = mock(:needs_to_be_saved? => false)
        @object.stub(:datastreams) { { :new_ds => mock_ds } }
        mock_ds.should_not_receive(:save)
        @object.save
      end
    end

    it "should save all changed attributes" do
      @object.label = "asdf"
      @object.should_receive(:datastreams).and_return({})
      @mock_repository.should_receive(:modify_object).with(hash_including(:pid => 'pid'))
      @object.save
    end
  end

  describe "delete" do
    before(:each) do
      @object = Rubydora::DigitalObject.new 'pid', @mock_repository
    end

    it "should call the Fedora REST API" do
      @mock_repository.should_receive(:purge_object).with({:pid => 'pid'})
      @object.delete
    end
  end

  describe "models" do
    before(:each) do
      @mock_repository.stub(:object) { <<-eos
        <http://repository/pid> <http://purl.org/dc/terms/title> "label"
      eos
      }
      @object = Rubydora::DigitalObject.new 'pid', @mock_repository
    end

    it "should add models to fedora" do
      @mock_repository.should_receive(:modify_object) do |params|
        params[:query].should =~ /asdf/
      end
      @object.models << "asdf"
      @object.save
    end

    it "should remove models from fedora" do
      @object.should_receive(:profile).any_number_of_times.and_return({'info:fedora/fedora-system:def/internal#mixinTypes' => ['asdf']})
      @mock_repository.should_receive(:modify_object) do |params|
        params[:query].should =~ /asdf/
      end
      @object.models.delete("asdf")
      @object.save
    end

    it "should be able to handle complete model replacemenet" do
      @mock_repository.should_receive(:modify_object) do |params|
        params[:query].should =~ /asdf/
      end
    
      @object.should_receive(:profile).any_number_of_times.and_return({'info:fedora/fedora-system:def/internal#mixinTypes' => ['asdf']})
      @object.models = '1234'
      @object.save

    end
  end

  describe "relations" do
    before(:each) do
      @mock_repository.stub(:object) { <<-eos
        <http://repository/pid> <http://purl.org/dc/terms/title> "label"
      eos
      }
      @object = Rubydora::DigitalObject.new 'pid', @mock_repository
    end

    it "should add related objects" do
      @mock_repository.should_receive(:modify_object) do |params|
        params[:query].should =~ /asdf/
      end
      @object.parts << 'asdf'
      @object.save
    end

    it "should remove related objects" do
      @object.parts = ['asdf']

      @mock_repository.should_receive(:modify_object) do |params|
        params[:query].should =~ /asdf/
      end
      @object.parts.delete('asdf')
      @object.save
    end
  end

  describe "versions" do
    before(:each) do
      @mock_repository.stub(:object) { <<-XML
        <http://repository/pid> <http://purl.org/dc/terms/title> "label"
      XML
      }

      @mock_repository.stub(:object_versions) { <<-XML
      <fedoraObjectHistory>
        <objectChangeDate>2011-09-26T20:41:02.450Z</objectChangeDate>
        <objectChangeDate>2011-10-11T21:17:48.124Z</objectChangeDate>
      </fedoraObjectHistory>
      XML
      }
      @object = Rubydora::DigitalObject.new 'pid', @mock_repository
    end

    it "should have a list of previous versions" do
      @object.versions.should have(2).items
      @object.versions.first.asOfDateTime.should == '2011-09-26T20:41:02.450Z'
    end

    it "should access versions as read-only copies" do
      expect { @object.versions.first.label = "asdf" }.to raise_error
    end

    it "should lookup content of datastream using the asOfDateTime parameter" do
      Rubydora::Datastream.should_receive(:new).with(anything, 'my_ds', hash_including(:asOfDateTime => '2011-09-26T20:41:02.450Z'))
      ds = @object.versions.first['my_ds']
    end
    
  end

  shared_examples "an object attribute" do
    subject { Rubydora::DigitalObject.new 'pid', @mock_repository }

    describe "getter" do
      it "should return the value" do
        subject.instance_variable_set("@#{method}", 'asdf')
        subject.send(method).should == 'asdf'
      end

      it "should look in the object profile" do
        subject.should_receive(:profile) { { Rubydora::DigitalObject::OBJ_ATTRIBUTES[method.to_sym].to_s => 'qwerty' } }
        subject.send(method).should == 'qwerty'
      end

    end

    describe "setter" do
      before do
        subject.stub(:datastreams => [])
      end
      it "should mark the object as changed after setting" do
        @mock_repository.should_receive(:object).with(:pid=>"pid").and_raise(RestClient::ResourceNotFound)
        subject.send("#{method}=", 'new_value')
        subject.should be_changed
      end

      it "should not mark the object as changed if the value does not change" do
        subject.stub(method) { 'zxcv' }
        subject.send("#{method}=", 'zxcv')
      end

      it "should appear in the save request" do 
        @mock_repository.should_receive(:ingest)
        @mock_repository.should_receive(:modify_object).with(hash_including(:query=>"INSERT { <http://repository/pid> <" + Rubydora::DigitalObject::OBJ_ATTRIBUTES[method.to_sym] + "> \"new_value\" .  }\nWHERE { }"))
        @mock_repository.should_receive(:object).with(:pid=>"pid").and_raise(RestClient::ResourceNotFound)
        subject.send("#{method}=", 'new_value')
        subject.save
      end
    end
  end

  describe "#state" do
    subject { Rubydora::DigitalObject.new 'pid', @mock_repository }

    describe "getter" do
      it "should return the value" do
        subject.instance_variable_set("@state", 'asdf')
        subject.state.should == 'asdf'
      end

      it "should look in the object profile" do
        subject.should_receive(:profile) { { Rubydora::DigitalObject::OBJ_ATTRIBUTES[:state].to_s => 'qwerty' } }
        subject.state.should == 'qwerty'
      end

      it "should fall-back to the set of default attributes" do
        @mock_repository.should_receive(:object).with(:pid=>"pid").and_raise(RestClient::ResourceNotFound)
        subject.stub(:default_attributes => {:state => 'zxcv'})
        subject.state.should include 'zxcv'
      end
    end

    describe "setter" do
      before do
        subject.stub(:datastreams => [])
      end
      it "should mark the object as changed after setting" do
        @mock_repository.should_receive(:object).with(:pid=>"pid").and_raise(RestClient::ResourceNotFound)
        subject.state= 'D'
        subject.should be_changed
      end

      it "should raise an error when setting an invalid value" do
        expect {subject.state= 'Q'}.to raise_error ArgumentError, "Allowed values for state are 'I', 'A' and 'D'. You provided 'Q'"
      end

      it "should not mark the object as changed if the value does not change" do
        subject.should_receive(:state) { 'A' }
        subject.state= 'A'
        subject.should_not be_changed
      end

      it "should appear in the save request" do 
        @mock_repository.should_receive(:ingest).with(hash_including(:pid => 'pid'))
        @mock_repository.should_receive(:modify_object).with(hash_including({:pid=>"pid", :query=>"DELETE { <http://repository/pid> <info:fedora3/state> \"A\" .  }\nINSERT { <http://repository/pid> <info:fedora3/state> \"A\" .  }\nWHERE { }"}))
        @mock_repository.should_receive(:object).with(:pid=>"pid").and_raise(RestClient::ResourceNotFound)
        subject.state='A'
        subject.save
      end
    end
  end

  describe "#ownerId" do
    it_behaves_like "an object attribute"
    let(:method) { 'ownerId' }
  end

  describe "#label" do
    it_behaves_like "an object attribute"
    let(:method) { 'label' }
  end

  describe "#lastModifiedDate" do
    it_behaves_like "an object attribute"
    let(:method) { 'lastModifiedDate' }
  end

  describe "#object_xml" do
    it "should return the FOXML record" do
      xml = File.read(File.join(File.dirname(__FILE__), '..', 'fixtures', 'audit_trail.foxml.xml'))
      @mock_repository.stub(:object_xml).with(hash_including(:pid => 'foo:bar')).and_return(xml)
      @object = Rubydora::DigitalObject.new 'foo:bar', @mock_repository
      @object.object_xml.should == @object.repository.object_xml(pid: 'foo:bar')
    end
  end
end
