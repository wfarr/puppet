module PuppetSpec::Matchers::Enumerable
  def have_items_in_order(*expected)
    EnumerableInOrderMatcher.new(expected)
  end

  class EnumerableInOrderMatcher
    def initialize(expected)
      @expected = expected
    end
    def matches?(actual_array)
      @actual_array = actual_array
      expected = @expected.dup

      actual_array.each do |actual|
        if (expected[0].matches?(actual))
          expected.shift
          break if expected.empty?
        end
      end

      return expected.empty?
    end

    def failure_message()
      "Elements in 'expected' array do not appear in order in 'actual' array; expected '#{@expected}', actual '#{@actual_array}'"
    end
  end
end
