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
  include PuppetSpec::Matchers::AllOf

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

    plan.order.should execute_in_order("Notify[base]", "Notify[top]")
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

    plan.order.should execute_in_any_order("Notify[top]", "Notify[base]")

    plan.graph.should_not any_of(
      have_a_dependency_between("Class[Base]", "Class[Top]"),
      have_a_dependency_between("Class[Top]", "Class[Base]"))
  end

  it "ensures that a contained element occurs after anything the container requires and before anything that requires the container" do
    pending("Need to implement contains()")

    plan = execution_plan_for(<<-MANIFEST)
      class apt_repo {
          notify { 'apt_repo': }
      }

      class uses_ssh {
          notify { "uses_ssh": }
      }

      class sshd {
        contains ssh::common
        notify { 'sshd': }
      }

      class ssh::common {
        notify { 'ssh::common': }
      }

      include sshd
      include uses_ssh
      include apt_repo

      Class[Apt_repo] -> Class[Sshd] -> Class[Uses_ssh]
    MANIFEST

    plan.order.should all_of(
      execute_in_order("Notify[apt_repo]", "Notify[sshd]", "Notify[uses_ssh]"),
      execute_in_order("Notify[apt_repo]", "Notify[sshd::common]", "Notify[uses_ssh]"))
  end

  it "ensures that an element contained by multiple containers happens after all dependencies of the containers" do
    pending("Need to implement contains()")

    plan = execution_plan_for(<<-MANIFEST)
      class apt_repo {
          notify { 'apt_repo': }
      }

      class ssh::server {
        contains ssh::common
        notify { 'ssh::server': }
      }

      class ssh::keys {
        contains ssh::common
        notify { 'ssh::client': }
      }

      class ssh::common {
        notify { 'ssh::common': }
      }

      include ssh::server
      include ssh::keys
      include apt_repo

      Class[apt_repo] -> Class[ssh::server]
    MANIFEST

    plan.order.should all_of(
      execute_in_order("Notify[apt_repo]", "Notify[ssh::server]"),
      execute_in_order("Notify[apt_repo]", "Notify[ssh::common]"),
      execute_in_any_order("Notify[apt_repo]", "Notify[ssh::keys]"))
  end

  it "ensures that an element contained by multiple containers happens before all dependents on the containers" do
    pending("Need to implement contains()")

    plan = execution_plan_for(<<-MANIFEST)
      class uses_ssh {
          notify { 'uses_ssh': }
      }

      class ssh::server {
        contains ssh::common
        notify { 'ssh::server': }
      }

      class ssh::keys {
        contains ssh::common
        notify { 'ssh::client': }
      }

      class ssh::common {
        notify { 'ssh::common': }
      }

      include uses_ssh
      include ssh::server
      include ssh::keys

      Class[ssh::server] -> Class[uses_ssh]
    MANIFEST

    plan.order.should all_of(
      execute_in_order("Notify[ssh::server]", "Notify[uses_ssh]"),
      execute_in_order("Notify[ssh::common]", "Notify[uses_ssh]"),
      execute_in_any_order("Notify[uses_ssh]", "Notify[ssh::keys]"))
  end

  def execute_in_order(*names)
    resources = names.collect { |name| a_resource_named(name) }
    have_items_in_order(*resources)
  end

  def execute_in_any_order(*names)
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
