require 'spec_helper'
require 'puppet_spec/compiler'

module PuppetSpec::Matchers::RAL
  def a_resource_named(name)
    ResourceNameMatcher.new(name)
  end

  def contain_edge(from, to)
    GraphEdgeMatcher.new(from, to)
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
end

describe "foo" do
  include PuppetSpec::Compiler
  include PuppetSpec::Matchers::RAL
  include PuppetSpec::Matchers::Enumerable

  class EvalResult
    attr_accessor :order, :graph

    def initialize
      @order = []
    end

    def scheduled?(status, resource)
      return true
    end

    def evaluate(resource)
      order << resource
      return Puppet::Resource::Status.new(resource)
    end
  end


  def do_eval(manifest)
    rv = EvalResult.new

    catalog = compile_to_catalog(manifest)
    catalog = catalog.to_ral
    catalog.host_config = false

    catalog.instance_variable_set(:@applying, true)

    transaction = Puppet::Transaction.new(catalog, nil, rv)
    transaction.evaluate

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
