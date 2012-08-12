#! /usr/bin/env ruby -S rspec
require 'spec_helper'
require 'facter/util/plist'

describe Puppet::Type.type(:user).provider(:osx) do
  let(:resource) do
    Puppet::Type.type(:user).new(
      :name => 'nonexistant_user',
      :provider => :osx
    )
  end

  let(:defaults) do
    {
      'UniqueID'         => '1000',
      'RealName'         => resource[:name],
      'PrimaryGroupID'   => '20',
      'UserShell'        => '/bin/bash',
      'NFSHomeDirectory' => "/Users/#{resource[:name]}"
    }
  end

  let(:user_plist_xml) do
    '<?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
            <key>dsAttrTypeStandard:NFSHomeDirectory</key>
            <array>
            <string>/Users/testuser</string>
            </array>
            <key>dsAttrTypeStandard:RealName</key>
            <array>
            <string>testuser</string>
            </array>
            <key>dsAttrTypeStandard:PrimaryGroupID</key>
            <array>
            <string>22</string>
            </array>
            <key>dsAttrTypeStandard:UniqueID</key>
            <array>
            <string>1000</string>
            </array>
            <key>dsAttrTypeStandard:RecordName</key>
            <array>
            <string>testuser</string>
            </array>
    </dict>
    </plist>'
  end

  let(:user_plist_hash) do
    {
      "dsAttrTypeStandard:RealName"         => ["testuser"],
      "dsAttrTypeStandard:NFSHomeDirectory" => ["/Users/testuser"],
      "dsAttrTypeStandard:PrimaryGroupID"   => ["22"],
      "dsAttrTypeStandard:UniqueID"         => ["1000"],
      "dsAttrTypeStandard:RecordName"       => ["testuser"]
    }
  end

  let(:user_plist_resource) do
    {
      :ensure   => :present,
      :provider => :osx,
      :comment  => 'testuser',
      :name     => 'testuser',
      :uid      => 1000,
      :gid      => 22,
      :home     => '/Users/testuser'
    }
  end

  let(:empty_plist) do
    '<?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    </dict>
    </plist>'
  end

  let(:provider) { resource.provider }

  describe '#create with defaults' do
    before :each do
      provider.expects(:dscl).with('.', '-create', "/Users/#{resource[:name]}").returns true
      provider.expects(:next_system_id).returns(defaults['UniqueID'])
      defaults.each do |key,val|
        provider.expects(:dscl).with('.', '-merge', "/Users/#{resource[:name]}", key, val)
      end
    end

    it 'should create a user with defaults given a minimal declaration' do
      provider.create
    end

    it 'should call #password= if a password attribute is specified' do
      resource[:password] = 'somepass'
      provider.expects(:password=).with('somepass')
      provider.create
    end

    #it 'should call #groups= if a groups attribute is specified' do
    #  resource[:groups] = 'groups'
    #  provider.expects(:groups=).with('some,groups')
    #  provider.create
    #end
  end

  describe 'self#instances' do
    it 'should create an array of provider instances' do
      provider.class.expects(:get_all_users).returns(['foo', 'bar'])
      ['foo', 'bar'].each do |user|
        provider.class.expects(:generate_attribute_hash).with(user).returns({})
      end
      provider.class.instances.size.should == 2
    end
  end

  describe 'self#get_all_users' do
    it 'should return a hash of user attributes' do
      provider.class.expects(:dscl).with('-plist', '.', 'readall', '/Users').returns(user_plist_xml)
      provider.class.get_all_users.should == user_plist_hash
    end

    it 'should return a hash when passed an empty plist' do
      provider.class.expects(:dscl).with('-plist', '.', 'readall', '/Users').returns(empty_plist)
      provider.class.get_all_users.should == {}
    end
  end

  describe 'self#generate_attribute_hash' do
    it 'should return :uid values as a Fixnum' do
      provider.class.generate_attribute_hash(user_plist_hash)[:uid].class.should == Fixnum
    end

    it 'should return :gid values as a Fixnum' do
      provider.class.generate_attribute_hash(user_plist_hash)[:gid].class.should == Fixnum
    end

    it 'should return a hash of resource attributes' do
      provider.class.generate_attribute_hash(user_plist_hash).should == user_plist_resource
    end
  end

  describe '#exists?' do
    # This test expects an error to be raised
    # I'm PROBABLY doing this wrong...
    it 'should return false if the dscl command errors out' do
      provider.exists?.should == false
    end

    it 'should return true if the dscl command does not error' do
      provider.expects(:dscl).with('.', 'read', "/Users/#{resource[:name]}").returns(user_plist_xml)
      provider.exists?.should == true
    end
  end

  describe '#delete' do
    it 'should call dscl when destroying/deleting a resource' do
      provider.expects(:dscl).with('.', '-delete', "/Users/#{resource[:name]}")
      provider.delete
    end
  end

  describe '#groups' do
    it 'should return a list of groups'
  end
end
