require 'spec_helper'

describe Rubydora::Repository do
  include Rubydora::FedoraUrlHelpers
  
  before(:each) do
    Rubydora::Repository.any_instance.stub(:version).and_return(4.0)
    @repository = Rubydora::Repository.new :url => 'http://localhost/fcrepo'
  end

  describe "initialize" do
    it "should symbolize config keys" do
      repository = Rubydora::Repository.new "validateChecksum"=> true
      repository.config[:validateChecksum].should be_true
    end
  end

  describe "base_url" do
    it "should be the configured base url" do
      repository = Rubydora::Repository.new :url => 'http://xyz'
      repository.base_url.should == "http://xyz"
    end
  end

  describe "client" do
    it "should return a RestClient resource" do
      client = @repository.client

      client.should be_a_kind_of(RestClient::Resource)
    end
  end

  describe "find" do
    it "should load objects by pid" do
      @mock_object = mock(Rubydora::DigitalObject)
      Rubydora::DigitalObject.should_receive(:find).with("pid", instance_of(Rubydora::Repository)).and_return @mock_object

      @repository.find('pid')
    end
  end

  describe "mint" do
    before do
      xml = "<http://localhost/fcrepo/fcr:pid> <info:fedora/fedora-system:def/internal#hasMember> <http://localhost/fcrepo/test:123> ."
      @repository.should_receive(:next_pid).and_return xml 
    end
    it "should call nextPID" do
      @repository.mint.should == '/test:123'
    end
  end

  describe "profile" do
    it "should map the fedora repository description to a hash" do
      @mock_response = mock()
      @mock_client = mock(RestClient::Resource)
      @mock_response.should_receive(:get).and_return <<-XML
      <http://localhost/fcrepo> <http://purl.org/dc/terms/title> "label" .
      XML
      @mock_client.should_receive(:[]).with(describe_repository_url).and_return(@mock_response)
      @repository.should_receive(:client).and_return(@mock_client)
      profile = @repository.profile
      profile['http://purl.org/dc/terms/title'].should include 'label'
    end
  end

  describe "ping" do
    it "should raise an error if a connection cannot be established" do
      @repository.should_receive(:profile).and_return nil
      lambda { @repository.ping }.should raise_error
    end

    it "should return true if a connection is established" do
      @repository.should_receive(:profile).and_return true
      @repository.ping.should == true
    end
  end

  describe "load_api_abstraction" do
    it "should load an abstraction layer for relationships for older versions of the fedora rest api" do
      Rubydora::Repository.any_instance.stub(:version).and_return(3.3)
      expect { Rubydora::Repository.new }.to raise_error
    end
  end

end
