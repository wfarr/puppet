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

module PuppetSpec::Matchers::Attributes
  def have_attribute(name, matcher)
    HaveAttributeMatcher.new(name, matcher)
  end

  class HaveAttributeMatcher
    def initialize(name, matcher)
      @name = name
      @matcher = matcher
    end

    def matches?(actual)
      @matcher.matches?(actual.send(@name))
    end

    def failure_message()
      "the attribute #{@name}: #{@matcher.failure_message}"
    end
  end
end

describe "Evaluation order" do
  include PuppetSpec::Compiler
  include PuppetSpec::Matchers::RAL
  include PuppetSpec::Matchers::Enumerable
  include PuppetSpec::Matchers::AnyOf
  include PuppetSpec::Matchers::AllOf
  include PuppetSpec::Matchers::Attributes

  it "ensures that a class required by another class is completed first" do
    #pending("The edge that forces the order seems to be missing")

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

    plan.should execute_in_order("Notify[base]", "Notify[top]")
    # Intuitively, the way we're expressing the expected edge for this test seems
    #  backwards as compared to the way the manifest reads.  We should discuss,
    #  and tweak the matcher implementation if we decide we'd rather express the
    #  edge source/target in the opposite order.
    plan.should have_a_dependency_between("Class[Base]", "Class[Intermediate]")
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

    plan.should execute_in_any_order("Notify[top]", "Notify[base]")

    plan.should_not any_of(
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

    plan.should all_of(
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
        notify { 'ssh::keys': }
      }

      class ssh::common {
        notify { 'ssh::common': }
      }

      include ssh::server
      include ssh::keys
      include apt_repo

      Class[apt_repo] -> Class[ssh::server]
    MANIFEST

    plan.should all_of(
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
        notify { 'ssh::keys': }
      }

      class ssh::common {
        notify { 'ssh::common': }
      }

      include uses_ssh
      include ssh::server
      include ssh::keys

      Class[ssh::server] -> Class[uses_ssh]
    MANIFEST

    plan.should all_of(
      execute_in_order("Notify[ssh::server]", "Notify[uses_ssh]"),
      execute_in_order("Notify[ssh::common]", "Notify[uses_ssh]"),
      execute_in_any_order("Notify[uses_ssh]", "Notify[ssh::keys]"))
  end

  it "transitive with multiple containment" do
    pending("Need to implement contains()")

    plan = execution_plan_for(<<-MANIFEST)
      class uses_ssh {
        notify { 'uses_ssh': }
      }

      class provides_ssh_pkgs {
        notify { 'provides_ssh_pkgs': }
      }

      class ssh::server {
        contains ssh::common
        notify { 'ssh::server': }
      }

      class ssh::keys {
        contains ssh::common
        notify { 'ssh::keys': }
      }

      class ssh::common {
        notify { 'ssh::common': }
      }

      include uses_ssh
      include ssh::server
      include ssh::keys

      Class[provides_ssh_pkgs] -> Class[ssh::server] -> Class[uses_ssh]
    MANIFEST

    plan.should all_of(
      execute_in_order("Notify[provides_ssh_pkgs]", "Notify[ssh::server]", "Notify[uses_ssh]"),
      execute_in_order("Notify[provides_ssh_pkgs]", "Notify[ssh::common]", "Notify[uses_ssh]"),
      execute_in_any_order("Notify[ssh:keys]", "Notify[uses_ssh]", "Notify[provides_ssh_pkgs]"))
  end

  it "should be transitive with a class that only declares other classes and has no resources itself" do
    pending("Need to implement contains()")

    plan = execution_plan_for(<<-MANIFEST)
      class uses_ssh {
        notify { 'uses_ssh': }
      }

      class provides_ssh_pkgs {
        notify { 'provides_ssh_pkgs': }
      }

      class ssh($client=true, $server=true) {
        contains ssh::common
        if $server {
          contains ssh::server
          Class[ssh::common] -> Class[ssh::server]
        }
        if $client {
          contains ssh::client
          Class[ssh::common] -> Class[ssh::client]
        }
        # (Note, there is no relationship between the client and server)
      }

      class ssh::server {
        notify { 'ssh::server': }
      }

      class ssh::client {
        notify { 'ssh::client': }
      }

      class ssh::common {
        notify { 'ssh::common': }
      }

      class { 'provides_ssh_pkgs': }
      -> class { 'ssh': }
      -> class { 'uses_ssh': }
    MANIFEST

    plan.should all_of(
      execute_in_order("Notify[provides_ssh_pkgs]", "Notify[ssh::common]", "Notify[ssh::server]", "Notify[uses_ssh]"),
      execute_in_order("Notify[provides_ssh_pkgs]", "Notify[ssh::common]", "Notify[ssh::client]", "Notify[uses_ssh]"),
      execute_in_any_order("Notify[ssh::client]", "Notify[ssh::server]"))
  end

  it "should be transitive with a class that only declares other classes and has no resources itself" do
    pending("Need to implement contains()")

    plan = execution_plan_for(<<-MANIFEST)
      class uses_ssh {
        notify { 'uses_ssh': }
      }

      class provides_ssh_pkgs {
        notify { 'provides_ssh_pkgs': }
      }

      class ssh::common {
        notify { 'ssh::common': }
      }

      class ssh::service {
        notify { 'ssh::service': }
      }

      class ssh::server {
        contains ssh::common
        contains ssh::service
        # NOTE: The anchor pattern breaks down here as well since the
        # ssh::server class contains the common class yet we're setting up a
        # requirement that the common class is managed before the server class.
        Class[ssh::common] -> Class[ssh::server]
        # We assume this (Class[ssh::server]) class will manage sshd_config
        notify { 'ssh::server': }
        # Notify the service to restart if configuration resources change.
        Class[ssh::common] ~> Class[ssh::service]
        # NOTE: The anchor pattern breaks down here because the ending anchor
        # requires the contained class.  This sets up a before relationship
        # which is mututally exclusive with this requirement.
        Class[ssh::server] ~> Class[ssh::service]
      }

      class ssh::client {
        contains ssh::common
        notify { 'ssh::client': }
      }

      class ssh::all {
        contains ssh::client
        contains ssh::server
      }

      # Note the notify relationships, not the before releationships!
      class { 'provides_ssh_pkgs': }
      ~> class { 'ssh::all': }
      ~> class { 'uses_ssh': }
    MANIFEST

    plan.should all_of(
      execute_in_order("Notify[provides_ssh_pkgs]", "Notify[ssh::common]", "Notify[ssh::server]", "Notify[ssh::service]", "Notify[uses_ssh]"),
      execute_in_order("Notify[provides_ssh_pkgs]", "Notify[ssh::common]", "Notify[ssh::client]", "Notify[uses_ssh]"),
      execute_in_any_order("Notify[ssh::client]", "Notify[ssh::server]"),
      execute_in_any_order("Notify[ssh::client]", "Notify[ssh::service]"))
  end

  def execute_in_order(*names)
    resources = names.collect { |name| a_resource_named(name) }
    have_attribute(:order, have_items_in_order(*resources))
  end

  def execute_in_any_order(*names)
    resources = names.collect { |name| a_resource_named(name) }
    have_attribute(:order, have_items_in_any_order(*resources))
  end

  def have_a_dependency_between(from_name, to_name)
    have_attribute(:graph, contain_edge_between(a_resource_named(from_name), a_resource_named(to_name)))
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
