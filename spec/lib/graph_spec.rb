require 'spec_helper'

describe Rubydora::Graph do
  PREDICATE_MAPPING = { :uuid => "info:fedora/fedora-system:def/internal#uuid"}
  GRAPH_DATA = <<-eos
<info:fedora/a-uri> <info:fedora/fedora-system:def/internal#uuid> "bf55d19a-f0da-4486-a2a2-2c5ed0de1a79" .
<info:fedora/a-uri> <info:fedora/fedora-system:def/internal#lastModifiedBy> "<anonymous>" .
<info:fedora/a-uri> <info:fedora/fedora-system:def/internal#numberOfChildren> "1"^^<http://www.w3.org/2001/XMLSchema#long> .
<info:fedora/a-uri> <info:fedora/fedora-system:def/internal#hasParent> <info:fedora/objects> .
<info:fedora/a-uri> <info:fedora/fedora-system:def/internal#createdBy> "<anonymous>" .
<info:fedora/a-uri> <info:fedora/fedora-system:def/internal#hasChild> <info:fedora/a-uri/58b527b4-9920-4c03-9581-773ba08c3f11> .
<info:fedora/a-uri> <info:fedora/fedora-system:def/internal#created> "2013-05-10T18:09:43.682+01:00"^^<http://www.w3.org/2001/XMLSchema#dateTime> .
<info:fedora/a-uri> <info:fedora/fedora-system:def/internal#mixinTypes> "fedora:resource" .
<info:fedora/a-uri> <info:fedora/fedora-system:def/internal#mixinTypes> "fedora:object" .
<info:fedora/a-uri> <info:fedora/fedora-system:def/internal#lastModified> "2013-05-15T16:17:35.198+01:00"^^<http://www.w3.org/2001/XMLSchema#dateTime> .
    eos

  subject do
    graph = Rubydora::Graph.new "info:fedora/a-uri", GRAPH_DATA, PREDICATE_MAPPING
  end
  
  it "should load up an RDF.rb graph from a string" do
    subject.rdf.should be_a_kind_of RDF::Graph
    subject.rdf.statements.should have(10).statements
  end

  it "should let me query by RDF predicate" do
    subject["info:fedora/fedora-system:def/internal#createdBy"].first.should == "<anonymous>"
    subject[RDF::URI.new("info:fedora/fedora-system:def/internal#createdBy")].first.should == "<anonymous>"
  end

  it "should map keywords to RDF terms" do
    subject[:uuid].first.should == "bf55d19a-f0da-4486-a2a2-2c5ed0de1a79"
  end

  it "should allow setters" do
    subject['some-predicate'] = "abc"
    subject['some-predicate'].should include "abc"
  end
end