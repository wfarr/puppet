require 'puppet/provider/package'

Puppet::Type.type(:package).provide(:munki, :parent => Puppet::Provider::Package) do
  desc "Manages Munki"

  commands :munki_do => '/usr/local/munki/munki_do.py'

  def exists?
    system "/usr/local/munki/munki_do.py --checkstate #{resource[:name]} --catalog testing"
  end

  def query
    state = system "/usr/local/munki/munki_do.py --checkstate #{resource[:name]} --catalog testing"
    if state
      return {:name => @resource[:name], :ensure => :present, :provider => :munki}
    else
      return nil
    end
  end

  def install
    munki_do('--install', resource[:name], '--catalog', 'testing')
  end

  def uninstall
    munki_do('--uninstall', resource[:name], '--catalog', 'testing')
  end
end
