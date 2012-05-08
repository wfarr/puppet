module PuppetSpec::Matchers::AnyOf
  def any_of(*matchers) 
    AnyOfMatcher.new(matchers)
  end

  class AnyOfMatcher
    def initialize(matchers)
      @matchers = matchers
    end

    def matches?(actual)
      @actual = actual
      @matchers.any? { |matcher| matcher.matches?(actual) }
    end

    def failure_message() 
      "Exepected any of [#{@matchers.join(', ')}], but was [#{@actual.join(', ')}]"
    end
  end
end
