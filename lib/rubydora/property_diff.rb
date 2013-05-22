module Rubydora
  class PropertyDiff
    attr_reader :subject, :property
    attr_accessor :old, :new

    def initialize subject, property
      self.subject = subject
      self.property = property
    end
  end
end