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
    include foo
}

class baz {
    require bar
    notify { "baz": }
}

include baz

MANIFEST
)

      eval_result.order.should be(["Notify['foo']", "Notify['bar'"])
      eval_result.graph.should be_contains_edge("Class['Bar']", "Class['Foo']")
    end
  end

end
