module PuppetSpec::Matchers::AllOf
  def all_of(*matchers) 
    AllOfMatcher.new(matchers)
  end

  class AllOfMatcher
    def initialize(matchers)
      @matchers = matchers
    end

    def matches?(actual)
      @actual = actual
      @matchers.all? { |matcher| matcher.matches?(actual) }
    end

    def failure_message() 
      "Exepected all of [#{@matchers.join(', ')}], but was [#{@actual.join(', ')}]"
    end
  end
end
