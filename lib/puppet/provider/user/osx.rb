require 'puppet'
require 'facter/util/plist'
require 'pp'

Puppet::Type.type(:user).provide :osx do
  desc "User management on OS X."

  commands :dscl => "/usr/bin/dscl"
  commands :groups_cmd => '/usr/bin/groups'
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
    # This method exists to map the dscl values to the correct Puppet
    # properties. This stays relatively consistent, but who knows what
    # Apple will do next year...
    {
      'RecordName'       => :name,
      'PrimaryGroupID'   => :gid,
      'NFSHomeDirectory' => :home,
      'UserShell'        => :shell,
      'UniqueID'         => :uid,
      'RealName'         => :comment,
      'Password'         => :password,
      'GeneratedUID'     => :guid,
      'IPAddress'        => :ip_address,
      'ENetAddress'      => :en_address,
      'GroupMembership'  => :members,
    }
  end

  def self.instances
    # This method assembles an array of provider instances containing
    # information about every instance of the user type on the system (i.e.
    # every user and its attributes).
    get_all_users.collect do |user|
      self.new(generate_attribute_hash(user))
    end
  end

  def self.get_all_users
    # Return an array of hashes containing information about every user on
    # the system.
    Plist.parse_xml(dscl '-plist', '.', 'readall', '/Users')
  end

  def self.generate_attribute_hash(input_hash)
    # This method accepts an individual user plist, passed as a hash, and
    # strips the dsAttrTypeStandard: prefix that dscl adds for each key.
    # An attribute hash is assembled and returned from the properties
    # supported by the user type.
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
    # Check for existance of a user. Use a dscl call to determine whether
    # the user exists. Rescue the DSCL error if the user doesn't exist
    # and return false.
    begin
      dscl '.', 'read', "/Users/#{@resource.name}"
    rescue
      return false
    end
  end

  def create
    puts 'Sudo create you a user, dammit'
  end

  def destroy
    puts 'Sudo remove you a user, dammit'
  end

  def groups
    # The groups command in OS X will return group membership for a passed
    # user. Values need to be returned as a comma-separated string of groups.
    groups_cmd(@resource.name).split.sort.join(',')
  end

  def password
    # Passwords are hard on OS X, yo. 10.6 used a SHA1 hash, 10.7 used a
    # salted-SHA512 hash, and 10.8 used a salted-PBKDF2 password. The
    # password getter method uses Puppet::Util::Package.versioncmp to
    # compare the version of OS X (it handles the condition that 10.10 is
    # a version greater than 10.2) and then calls the correct method to
    # retrieve the password hash
    if (Puppet::Util::Package.versioncmp(Facter.value(:macosx_productversion_major), '10.7') == -1)
      # Calculate SHA1 Hash
      'password'
    else
      shadow_hash_data = get_shadowhashdata
      return '*' if shadow_hash_data.empty?
      embedded_binary_plist = get_embedded_binary_plist(shadow_hash_data)
      if embedded_binary_plist['SALTED-SHA512']
        get_salted_sha512(embedded_binary_plist)
      else
        # Do 10.8 Hackery Here
      end
    end
  end

  def get_shadowhashdata
    # In versions of OS X greater than 10.6, every user with a password has a
    # ShadowHashData key which contains an embedded binary plist. This method
    # uses dscl to get that specific key.
    Plist.parse_xml(dscl '-plist', '.', 'read', "/Users/#{@resource.name}", 'ShadowHashData')
  end

  def get_embedded_binary_plist(shadow_hash_data)
    # The plist embedded in the ShadowHashData key is a binary plist. The
    # facter/util/plist library doesn't read binary plists, so we need to
    # extract the binary plist, convert it to XML, and return it.
    embedded_binary_plist = Array(shadow_hash_data['dsAttrTypeNative:ShadowHashData'][0].gsub(' ', '')).pack('H*')
    convert_binary_to_xml(embedded_binary_plist)
  end

  def convert_binary_to_xml(plist_data)
    # This method will accept a binary plist (as a string) and convert it to a
    # hash via Plist::parse_xml.
    Puppet.debug('Converting binary plist to XML')
    Puppet.debug('Executing: \'plutil -convert xml1 -o - -\'')
    IO.popen('plutil -convert xml1 -o - -', mode='r+') do |io|
      io.write plist_data
      io.close_write
      @converted_plist = io.read
    end
    Puppet.debug('Converting XML values to a hash.')
    @plist_hash = Plist::parse_xml(@converted_plist)
    @plist_hash
  end

  def get_salted_sha512(embedded_binary_plist)
    # The salted-SHA512 password hash in 10.7 is stored in the 'SALTED-SHA512'
    # key as binary data. That data is extracted and converted to a hex string.
    embedded_binary_plist['SALTED-SHA512'].string.unpack("H*")[0]
  end
end
