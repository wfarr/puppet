require 'puppet'
require 'facter/util/plist'
require 'fileutils'
require 'pp'

Puppet::Type.type(:user).provide :osx do
  desc "User management on OS X."

  commands :dscl => "/usr/bin/dscl"
  confine :operatingsystem => :darwin
  defaultfor :operatingsystem => :darwin

  # Need this to create getter/setter methods automagically
  # This command creates methods that return @property_hash[:value]
  mk_resource_methods

  # JJM: OS X can manage passwords.
  #      This needs to be a special option to dscl though (-passwd)
  has_feature :manages_passwords

  # JJM: comment matches up with the /etc/passwd concept of an user
  #options :comment, :key => "realname"
  #options :password, :key => "passwd"
  #autogen_defaults :home => "/var/empty", :shell => "/usr/bin/false"

  #verify :gid, "GID must be an integer" do |value|
  #  value.is_a? Integer
  #end

  #verify :uid, "UID must be an integer" do |value|
  #  value.is_a? Integer
  #end

  def self.ds_to_ns_attribute_map
    {
      'RecordName' => :name,
      'PrimaryGroupID' => :gid,
      'NFSHomeDirectory' => :home,
      'UserShell' => :shell,
      'UniqueID' => :uid,
      'RealName' => :comment,
      'Password' => :password,
      'GeneratedUID' => :guid,
      'IPAddress'    => :ip_address,
      'ENetAddress'  => :en_address,
      'GroupMembership' => :members,
    }
  end

  def autogen_comment
    @resource[:name].capitalize
  end

  def self.instances
    get_all_users.collect do |user|
      self.new(generate_attribute_hash(user))
    end
  end

  def self.get_all_users
    Plist.parse_xml(dscl '-plist', '.', 'readall', '/Users')
  end

  def self.generate_attribute_hash(input_hash)
    attribute_hash = {}
    input_hash.keys.each do |key|
      ds_attribute = key.sub("dsAttrTypeStandard:", "")
      next unless ds_to_ns_attribute_map.keys.include?(ds_attribute)
      ds_value = input_hash[key]
      case ds_to_ns_attribute_map[ds_attribute]
        when :gid, :uid
          # OS X stores objects like uid/gid as strings.
          # Try casting to an integer for these cases to be
          # consistent with the other providers and the group type
          # validation
          begin
            ds_value = Integer(ds_value[0])
          rescue ArgumentError
            ds_value = ds_value[0]
          end
        else ds_value = ds_value[0]
      end
      attribute_hash[ds_to_ns_attribute_map[ds_attribute]] = ds_value
    end
    attribute_hash[:ensure] = :present
    attribute_hash[:provider] = :osx
    attribute_hash
  end

  def exists?
    if @property_hash[:ensure] == :present
      true
    else
      false
    end
  end

  def create

  end

  def destroy

  end

  def groups
    'these,groups,now'
  end
end
