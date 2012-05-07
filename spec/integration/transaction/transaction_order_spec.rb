require 'spec_helper'
require 'puppet_spec/compiler'

module PuppetSpec::Matchers::RAL
  def a_resource_named(name)
    ResourceNameMatcher.new(name)
  end

  def contain_edge_between(from, to)
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

describe "Evaluation order" do
  include PuppetSpec::Compiler
  include PuppetSpec::Matchers::RAL
  include PuppetSpec::Matchers::Enumerable

  it "ensures that a class required by another class is completed first" do
    plan = execution_plan_for(<<-MANIFEST)
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

    plan.order.should have_items_in_order(a_resource_named("Notify[base]"), a_resource_named("Notify[top]"))
    #plan.graph.should contain_edge_between(a_resource_named("Class[Intermediate]"), a_resource_named("Class[Base]"))
  end

  it "does not link a class included by another class in any way" do
    plan = execution_plan_for(<<-MANIFEST)
      class base {
          notify { 'base': }
      }

      class top {
          include base
          notify { "top": }
      }

      include top
    MANIFEST

    plan.order.should have_items_in_any_order(a_resource_named("Notify[top]"), a_resource_named("Notify[base]"))

    plan.graph.should_not contain_edge_between(a_resource_named("Class[Base]"), a_resource_named("Class[Top]"))
    plan.graph.should_not contain_edge_between(a_resource_named("Class[Top]"), a_resource_named("Class[Base]"))
  end

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

  ExecutionPlan = Struct.new(:order, :graph)

  def execution_plan_for(manifest)
    recorder = EvaluationRecorder.new

    ral = compile_to_catalog(manifest).to_ral

    transaction = Puppet::Transaction.new(ral, nil, recorder)
    transaction.evaluate

    return ExecutionPlan.new(recorder.order, transaction.relationship_graph)
  end
end
