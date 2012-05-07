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
  include PuppetSpec::Matchers::AnyOf

  it "ensures that a class required by another class is completed first" do
    pending("The edge that forces the order seems to be missing")

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

    plan.order.should plan_to_execute_in_order("Notify[base]", "Notify[top]")
    plan.graph.should have_a_dependency_between("Class[Intermediate]", "Class[Base]")
  end

  it "does not link a class included by another class in any way" do
    plan = execution_plan_for(<<-MANIFEST)
      class first {
          notify { 'first': }
      }

      class last {
          notify { "last": }
      }

      class base {
          notify { 'base': }
      }

      class top {
          include base
          notify { "top": }
      }

      include top
      include first
      include last
      Class[First] -> Class[Top] -> Class[Last]
    MANIFEST

    plan.order.should plan_to_execute_in_any_order("Notify[top]", "Notify[base]")

    plan.graph.should_not have_a_dependency_between("Class[Base]", "Class[Top]")
    plan.graph.should_not have_a_dependency_between("Class[Top]", "Class[Base]")
  end

  it "does not link a class included by another class in any way" do
    pending("Need to implement contains()")

    plan = execution_plan_for(<<-MANIFEST)
      class first {
          notify { 'first': }
      }

      class last {
          notify { "last": }
      }

      class container {
        contains contained
        notify { 'container': }
      }

      class contained {
        notify { 'contained': }
      }

      include first
      include container
      include last

      Class[First] -> Class[Container] -> Class[Last]
    MANIFEST

    plan.order.should any_of(
      plan_to_execute_in_order("Notify[first]", "Notify[container]", "Notify[contained]", "Notify[last]"),
      plan_to_execute_in_order("Notify[first]", "Notify[contained]", "Notify[container]", "Notify[last]"))
  end

  def plan_to_execute_in_order(*names)
    resources = names.collect { |name| a_resource_named(name) }
    have_items_in_order(*resources)
  end

  def plan_to_execute_in_any_order(*names)
    resources = names.collect { |name| a_resource_named(name) }
    have_items_in_any_order(*resources)
  end

  def have_a_dependency_between(from_name, to_name)
    contain_edge_between(a_resource_named(from_name), a_resource_named(to_name))
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
