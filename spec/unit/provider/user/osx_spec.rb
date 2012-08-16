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

  let(:group_plist_hash) do
    [{
      'dsAttrTypeStandard:RecordName'      => ['testgroup'],
      'dsAttrTypeStandard:GroupMembership' => [
                                                'testuser',
                                                'nonexistant_user',
                                                'jeff',
                                                'zack'
                                              ],
      'dsAttrTypeStandard:GroupMembers'    => [
                                                'guidtestuser',
                                                'guidjeff',
                                                'guidzack'
                                              ],
    },
    {
      'dsAttrTypeStandard:RecordName'      => ['second'],
      'dsAttrTypeStandard:GroupMembership' => [
                                                'nonexistant_user',
                                                'jeff',
                                              ],
      'dsAttrTypeStandard:GroupMembers'    => [
                                                'guidtestuser',
                                                'guidjeff',
                                              ],
    },
    {
      'dsAttrTypeStandard:RecordName'      => ['third'],
      'dsAttrTypeStandard:GroupMembership' => [
                                                'jeff',
                                                'zack'
                                              ],
      'dsAttrTypeStandard:GroupMembers'    => [
                                                'guidjeff',
                                                'guidzack'
                                              ],
    }]
  end

  let(:group_plist_hash_guid) do
    [{
      'dsAttrTypeStandard:RecordName'      => ['testgroup'],
      'dsAttrTypeStandard:GroupMembership' => [
                                                'testuser',
                                                'jeff',
                                                'zack'
                                              ],
      'dsAttrTypeStandard:GroupMembers'    => [
                                                'guidnonexistant_user',
                                                'guidtestuser',
                                                'guidjeff',
                                                'guidzack'
                                              ],
    },
    {
      'dsAttrTypeStandard:RecordName'      => ['second'],
      'dsAttrTypeStandard:GroupMembership' => [
                                                'testuser',
                                                'jeff',
                                                'zack'
                                              ],
      'dsAttrTypeStandard:GroupMembers'    => [
                                                'guidtestuser',
                                                'guidjeff',
                                                'guidzack'
                                              ],
    },
    {
      'dsAttrTypeStandard:RecordName'      => ['third'],
      'dsAttrTypeStandard:GroupMembership' => [
                                                'testuser',
                                                'jeff',
                                                'zack'
                                              ],
      'dsAttrTypeStandard:GroupMembers'    => [
                                                'guidnonexistant_user',
                                                'guidtestuser',
                                                'guidjeff',
                                                'guidzack'
                                              ],
    }]
  end

  let(:empty_plist) do
    '<?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    </dict>
    </plist>'
  end

  let(:shadow_hash_data_plist) do
    '<?xml version="1.0" encoding="UTF-8"?>
     <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
     <plist version="1.0">
     <dict>
       <key>dsAttrTypeNative:ShadowHashData</key>
       <array>
         <string>62706c69 73743030 d101025d 53414c54 45442d53 48413531 324f1044 7ea7d592 131f57b2 c8f8bdbc ec8d9df1 2128a386 393a4f00 c7619bac 2622a44d 451419d1 1da512d5 915ab98e 39718ac9 4083fe2e fd6bf710 a54d477f 8ff735b1 2587192d 080b1900 00000000 00010100 00000000 00000300 00000000 00000000 00000000 000060</string>
       </array>
     </dict>
     </plist>'
  end

  let(:shadow_hash_data_hash) do
    {
      'dsAttrTypeNative:ShadowHashData' => ['62706c69 73743030 d101025d 53414c54 45442d53 48413531 324f1044 7ea7d592 131f57b2 c8f8bdbc ec8d9df1 2128a386 393a4f00 c7619bac 2622a44d 451419d1 1da512d5 915ab98e 39718ac9 4083fe2e fd6bf710 a54d477f 8ff735b1 2587192d 080b1900 00000000 00010100 00000000 00000300 00000000 00000000 00000000 000060']
    }
  end

  let(:salted_sha512_password_hash) do
    '7ea7d592131f57b2c8f8bdbcec8d9df12128a386393a4f00c7619bac2622a44d451419d11da512d5915ab98e39718ac94083fe2efd6bf710a54d477f8ff735b12587192d'
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
    it "should return a list of groups if the user's name matches GroupMembership" do
      provider.expects(:get_list_of_groups).returns(group_plist_hash)
      provider.expects(:get_attribute_from_dscl).with('Users', 'GeneratedUID').returns(['guidnonexistant_user'])
      provider.groups.should == 'second,testgroup'
    end

    it "should return a list of groups if the user's GUID matches GroupMembers" do
      provider.expects(:get_list_of_groups).returns(group_plist_hash_guid)
      provider.expects(:get_attribute_from_dscl).with('Users', 'GeneratedUID').returns(['guidnonexistant_user'])
      provider.groups.should == 'testgroup,third'
    end
  end

  describe '#groups=' do
    it 'should call dscl to add necessary groups' do
      provider.expects(:groups).returns('two,three')
      provider.expects(:get_attribute_from_dscl).with('Users', 'GeneratedUID').returns({'dsAttrTypeStandard:GeneratedUID' => ['guidnonexistant_user']})
      provider.expects(:dscl).with('.', '-merge', '/Groups/one', 'GroupMembership', 'nonexistant_user')
      provider.expects(:dscl).with('.', '-merge', '/Groups/one', 'GroupMembers', 'guidnonexistant_user')
      provider.groups= 'one,two,three'
    end
  end

  describe '#password' do
    ['10.5', '10.6'].each do |os_ver|
      it "should call the get_sha1 method on #{os_ver}" do
        Facter.expects(:value).with(:macosx_productversion_major).returns(os_ver)
        provider.expects(:get_attribute_from_dscl).with('Users', 'GeneratedUID').returns({'dsAttrTypeStandard:GeneratedUID' => ['guidnonexistant_user']})
        provider.expects(:get_sha1).with('guidnonexistant_user').returns('password')
        provider.password.should == 'password'
      end
    end

    it 'should call the get_salted_sha512 method on 10.7 and return the correct hash' do
      Facter.expects(:value).with(:macosx_productversion_major).returns('10.7')
      provider.expects(:get_attribute_from_dscl).with('Users', 'ShadowHashData').returns(shadow_hash_data_hash)
      provider.password.should == salted_sha512_password_hash
    end

    it 'should handle returning the password on 10.8'
  end

  describe '#password=' do
    ['10.7', '10.8'].each do |os_ver|
      it "should call write_password_to_users_plist on version #{os_ver}" do
        Facter.expects(:value).with(:macosx_productversion_major).returns('10.7')
        provider.expects(:write_password_to_users_plist).with('password')
        provider.password = 'password'
      end
    end

    it 'should handle password= on 10.5 and 10.6'
  end
end
