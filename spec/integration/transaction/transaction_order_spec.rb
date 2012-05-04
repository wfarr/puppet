require 'spec_helper'
require 'puppet_spec/compiler'

describe "foo" do
  include PuppetSpec::Compiler

  class EvalResult
    attr_accessor :order, :graph

    def initialize
      @order = []
    end

    def scheduled?(status, resource)
      return true
    end

    def evaluate(resource)
      puts "EVALUATING RESOURCE"
      pp resource
      order << resource
      return Puppet::Resource::Status.new(resource)
    end
  end

  class ResourceNameMatcher
    def initialize(expected_name)
      @expected_name = expected_name
    end

    def matches?(actual)
      @expected_name == actual.to_s
    end

    def to_s()
      @expected_name
    end
  end

  def a_resource_named(name)
    ResourceNameMatcher.new(name)
  end

  class ArrayInOrderMatcher
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

  def have_items_in_order(*expected)
    ArrayInOrderMatcher.new(expected)
  end

  class GraphEdgeMatcher
    def initialize(from, to)
      @from = from
      @to = to
    end
    def matches?(graph)
      @graph = graph
      graph.edges.any? do |edge|
        print "Edge type: '#{edge.class}'"
        puts "Source to_s: '#{edge.source.to_s}'"
        puts "Source class: '#{edge.source.class}'"
        puts "Target to_s: '#{edge.target.to_s}'"
        puts "Target class: '#{edge.target.class}'"
        pp edge
        @from.matches?(edge.source) && @to.matches?(edge.target)
      end
    end

    def failure_message()
      "Expected resource '#{@from}' to have an edge to '#{@to}'; actual edges:\n#{@graph.edges.join("\n")}"
    end
  end

  def contain_edge(from, to)
    GraphEdgeMatcher.new(from, to)
  end


  def do_eval(manifest)
    rv = EvalResult.new

    catalog = compile_to_catalog(manifest)
    catalog = catalog.to_ral
    catalog.host_config = false

    catalog.instance_variable_set(:@applying, true)

    transaction = Puppet::Transaction.new(catalog, nil, rv)

    begin
      transaction.evaluate
      pp "Finished eval"
    rescue => detail
      pp "AAAGGGGGGGGGGGGHHHHHH"
      puts detail
      puts Puppet::Util.pretty_backtrace(detail.backtrace)
    ensure
      pp transaction.report.status
    end

    rv.graph = transaction.relationship_graph

    return rv
  end


  describe "bar" do
    it "should baz" do
      eval_result = do_eval( <<-MANIFEST

class foo {
    notify { 'foo': }
}

class bar {
    #include foo
    require foo
}

class baz {
    require bar
    notify { "baz": }
}

include baz

MANIFEST
)

      #eval_result.order.should have_exactly_in_order()
      eval_result.order.should have_items_in_order(a_resource_named("Notify[foo]"), a_resource_named("Notify[baz]"))
      #eval_result.graph.should contain_edge(a_resource_named("Class[Bar]"), a_resource_named("Class[Foo]"))
    end
  end

end
