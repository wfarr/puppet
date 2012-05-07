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

  class EvaluationRecorder
    attr_reader :order

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

  EvaluationResult = Struct.new(:order, :graph)

  def do_eval(manifest)
    recorder = EvaluationRecorder.new

    ral = compile_to_catalog(manifest).to_ral

    transaction = Puppet::Transaction.new(ral, nil, recorder)
    transaction.evaluate

    return EvaluationResult.new(recorder.order, transaction.relationship_graph)
  end

  it "ensures that a class required by another class is completed first" do
    eval_result = do_eval(<<-MANIFEST)
      class base {
          notify { 'base': }
      }

      class intermediate {
          require base
      }

      class top {
          require intermediate
          notify { "top": }
      }

      include top
    MANIFEST

    eval_result.order.should have_items_in_order(a_resource_named("Notify[base]"), a_resource_named("Notify[top]"))
    #eval_result.graph.should contain_edge(a_resource_named("Class[Bar]"), a_resource_named("Class[Foo]"))
  end
end
