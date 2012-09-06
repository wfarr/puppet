require 'puppet'
require 'facter/util/plist'
require 'fileutils'
require 'pp'

Puppet::Type.type(:group).provide :directoryservice do
  desc "Group management on OS X."

  commands :dscl        => "/usr/bin/dscl"
  commands :uuidgen     => "/usr/bin/uuidgen"
  commands :dseditgroup => 'dseditgroup'

  confine :operatingsystem => :darwin
  defaultfor :operatingsystem => :darwin

  # Need this to create getter/setter methods automagically
  # This command creates methods that return @property_hash[:value]
  mk_resource_methods

  has_feature :manages_members

  def self.ds_to_ns_attribute_map
    {
      'RecordName'      => :name,
      'PrimaryGroupID'  => :gid,
      'RealName'        => :comment,
      'Password'        => :password,
      'GeneratedUID'    => :guid,
      'GroupMembership' => :members,
      'GroupMembers'    => :guid_list,
    }
  end

  def self.ns_to_ds_attribute_map
    @ns_to_ds_attribute_map ||= ds_to_ns_attribute_map.invert
  end

  def self.instances
    get_all_groups.collect do |group|
      self.new(generate_attribute_hash(group))
    end
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
        when :gid
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

  #  Prefetching is necessary to use @property_hash inside any setter methods
  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  def self.get_attribute_from_dscl(path, username, keyname)
    # Perform a dscl lookup at the path specified for the specific keyname
    # value. The value returned is the first item within the array returned
    # from dscl
    Plist.parse_xml(dscl '-plist', '.', 'read', "/#{path}/#{username}", keyname)
  end

##                   ##
## Ensurable Methods ##
##                   ##

  def exists?
    begin
      dscl '.', 'read', "/Groups/#{@resource.name}"
    rescue
      return false
    end
    true
  end

  def create
    dscl '.', '-create', "/Groups/#{@resource.name}"

    # Generate a GUID for the new user
    @guid = uuidgen

    # Get an array of valid User type properties
    valid_properties = Puppet::Type.type('Group').validproperties

    # GUID is not a valid user type property, but since we generated it
    # and set it to be @guid, we need to set it with dscl. To do this,
    # we add it to the array of valid User type properties.
    valid_properties.unshift(:guid)

    # Iterate through valid User type properties
    valid_properties.each do |attribute|
      next if attribute == :ensure
      value = @resource.should(attribute)

      # Value defaults
      if value.nil?
        value = @guid if attribute == :guid
        value = next_system_id if attribute == :gid
      end

      if value != '' and not value.nil?
        begin
          case attribute
          when :guid
            dscl '.', '-changei', "/Groups/#{@resource.name}", self.class.ns_to_ds_attribute_map[attribute], '1', @guid
          when :members
            value.each do |user|
              #begin
              #  dseditgroup '-o edit -n . -a', user,  '-t user', @resource.name
              #rescue Puppet::ExecutionFailure => e
              #  debug("dseditgroup attempted to add the user #{user} to the " +
              #        "#{@resource.name} group, but that user did not exist.")
              #  puts e.inspect
              #end
              dscl '.', '-merge', "/Groups/#{@resource.name}", 'GroupMembership', group
            end
          else
            dscl '.', '-merge', "/Groups/#{@resource.name}", self.class.ns_to_ds_attribute_map[attribute], value
          end
        rescue => e
         fail("Could not create #{@resource.class.name} #{@resource.name}: #{e.inspect}")
        end
      end
    end
  end

  def delete
    # This method is called when ensure => absent has been set.
    # Deleting a user is handled by dscl
    dscl '.', '-delete', "/Groups/#{@resource.name}"
  end

  ##                ##
  ## Helper Methods ##
  ##                ##

  def next_system_id(min_id=20)
    # Get the next available uid on the system by getting a list of user ids,
    # sorting them, grabbing the last one, and adding a 1. Scientific stuff here.
    dscl_output = dscl '.', '-list', '/Groups', 'gid'
    # We're ok with throwing away negative uids here. Also, remove nil values.
    user_ids = dscl_output.split.compact.collect { |l| l.to_i if l.match(/^\d+$/) }
    ids = user_ids.compact!.sort! { |a,b| a.to_f <=> b.to_f }
    # We're just looking for an unused id in our sorted array.
    ids.each_index do |i|
      next_id = ids[i] + 1
      return next_id if ids[i+1] != next_id and next_id >= min_id
    end
  end
end
