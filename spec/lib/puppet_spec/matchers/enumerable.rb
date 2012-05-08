module PuppetSpec::Matchers::Enumerable
  def have_items_in_order(*expected)
    EnumerableItemsInOrderMatcher.new(expected)
  end

  def have_items_in_any_order(*expected)
    EnumerableItemsInAnyOrderMatcher.new(expected)
  end

  class EnumerableItemsInOrderMatcher
    def initialize(expected)
      @expected = expected
    end

    def matches?(actual)
      @actual = actual
      expected = @expected.dup

      actual.each do |actual|
        if (expected[0].matches?(actual))
          expected.shift
          break if expected.empty?
        end
      end

      return expected.empty?
    end

    def failure_message()
      "Elements in 'expected' do not appear in order in 'actual'; expected '#{@expected}', actual '#{@actual}'"
    end

    def to_s()
      "in order [#{@expected.join(', ')}]"
    end
  end

  class EnumerableItemsInAnyOrderMatcher
    def initialize(expected)
      @expected = expected
    end

    def matches?(actual)
      @actual = actual
      expected = @expected.dup

      actual.each do |actual|
        match = expected.find do |matcher|
          matcher.matches?(actual)
        end

        if (match)
          expected.delete(match)
        end
      end

      return expected.empty?
    end

    def failure_message()
      "Elements in 'expected' do not appear in 'actual'; expected '#{@expected}', actual '#{@actual}'"
    end

    def to_s()
      "in any order [#{@expected.join(', ')}]"
    end
  end
end
