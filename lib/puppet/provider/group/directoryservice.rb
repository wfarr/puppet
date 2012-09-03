require 'puppet'
require 'facter/util/plist'
require 'fileutils'
require 'pp'

Puppet::Type.type(:group).provide :directoryservice do
  desc "Group management on OS X."

  commands :dscl => "/usr/bin/dscl"
  confine :operatingsystem => :darwin
  defaultfor :operatingsystem => :darwin

  # Need this to create getter/setter methods automagically
  # This command creates methods that return @property_hash[:value]
  mk_resource_methods

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

  def self.instances
    @array = []
    get_all_groups.collect do |user|
      @array << self.new(generate_attribute_hash(user))
    end
    pp @array
    @array
  end

  def self.get_all_groups
    Plist.parse_xml(dscl '-plist', '.', 'readall', '/Groups')
  end

  def self.generate_attribute_hash(input_hash)
    attribute_hash = {}
    input_hash.keys.each do |key|
      ds_attribute = key.sub("dsAttrTypeStandard:", "")
      next unless ds_to_ns_attribute_map.keys.include?(ds_attribute)
      ds_value = input_hash[key]
      case ds_to_ns_attribute_map[ds_attribute]
        when :members
          ds_value = ds_value
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
    attribute_hash[:ensure]   = :present
    attribute_hash[:provider] = :directoryservice
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
end
