module PuppetSpec::Compiler
  def compile_to_catalog(string, node = Puppet::Node.new('foonode'))
    # without setting this 'clientversion' property of the node, we fail the
    #   test in Puppet::Parser::Resource#metaparam_compatibility_mode?.  This
    #   prevents some important metaparameters (e.g. 'require') from showing up in
    #   our catalog.
    node.parameters['clientversion'] = Puppet.version
    Puppet[:code] = string
    Puppet::Parser::Compiler.compile(node)
  end
end
