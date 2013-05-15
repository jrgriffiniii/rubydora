require 'rdf'
require 'rdf/ntriples'

module Rubydora
  class Graph
  	
  	attr_reader :subject, :mapping

    def initialize subject, content, mapping = {}
      @subject = subject if subject.is_a? RDF::Term
      @subject ||= RDF::URI.new(subject)

      @mapping = mapping
	    
      data = StringIO.new(content)
      RDF::Reader.for(:ntriples).new(data) do |reader|
	      reader.each_statement do |statement|
	        rdf << statement
	      end
	    end
    end

    def find term, &block
    	enum = rdf.query([subject, term, nil])

      enum.map { |x| x.object.to_s }
    end

    def [] term_or_keyword
      find map_keyword_to_term(term_or_keyword)
    end

    def has_key? term_or_keyword
      find(map_keyword_to_term(term_or_keyword)).length > 0
    end

    def map_keyword_to_term term_or_keyword
      term = term_or_keyword if term_or_keyword.is_a? RDF::Term
      term ||= mapping[term_or_keyword]
      term ||= term_or_keyword

      if term.is_a? String
        term = RDF::URI.new(term)
      end

      term
    end

    def rdf
      @rdf ||= RDF::Graph.new
    end
  end
end