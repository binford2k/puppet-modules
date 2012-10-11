require 'etc'
require 'fileutils'
require 'enumerator'
require 'pathname'
require 'puppet/util/symbolic_file_mode'

Puppet::Type.newtype(:noxdir) do
  include Puppet::Util::MethodHelper
  include Puppet::Util::Checksums
  include Puppet::Util::SymbolicFileMode
  include Puppet::Util::Warnings

  @doc = "Manages directories without the x permission set.
  
    Puppet does not let you manage directories without x because that is almost
    never what you really want. Nevertheless, there are a few--very few--use cases
    in which you might want to do so. This resource type allows you to do so.
    
    You can manage the user, group, and mode. Because of the restrictions on
    a non-traversable directory, no other attributes are possible.

    **Autorequires:** If Puppet is managing the user or group that owns a
    file, the noxdir resource will autorequire them. If Puppet is managing any
    parent directories of a noxdir, the noxdir resource will autorequire them."
  
  ensurable
  
  def initialize(hash)
    super
    @stat = :needs_stat
  end

  newparam(:path) do
    desc 'The full path of the directory to manage'
    isnamevar

    validate do |value|
      unless Puppet::Util.absolute_path?(value)
        fail Puppet::Error, "Directory paths must be fully qualified, not '#{value}'"
      end
    end
  end

  newproperty(:owner) do
    desc <<-EOT
    The user to whom the file should belong.  Argument can be a user name or a
    user ID.

    On Windows, a group (such as "Administrators") can be set as a file's owner
    and a user (such as "Administrator") can be set as a file's group; however,
    a file's owner and group shouldn't be the same. (If the owner is also
      the group, files with modes like `0640` will cause log churn, as they
      will always appear out of sync.)
    EOT

    validate do |user|
      raise(Puppet::Error, "Invalid user name '#{user.inspect}'") unless user and user != ""
    end

    def insync?(current)
      # We don't want to validate/munge users until we actually start to
      # evaluate this property, because they might be added during the catalog
      # apply.
      @should.map! do |val|
        provider.name2uid(val) or raise "Could not find user #{val}"
      end

      return true if @should.include?(current)

      unless Puppet.features.root?
        warnonce "Cannot manage ownership unless running as root"
        return true
      end

      false
    end

    # We want to print names, not numbers
    def is_to_s(currentvalue)
      provider.uid2name(currentvalue) || currentvalue
    end

    def should_to_s(newvalue)
      provider.uid2name(newvalue) || newvalue
    end
  end

  newproperty(:group) do
    desc <<-EOT
      Which group should own the file.  Argument can be either a group
      name or a group ID.

      On Windows, a user (such as "Administrator") can be set as a file's group
      and a group (such as "Administrators") can be set as a file's owner;
      however, a file's owner and group shouldn't be the same. (If the owner
      is also the group, files with modes like `0640` will cause log churn, as
      they will always appear out of sync.)
    EOT

    validate do |group|
      raise(Puppet::Error, "Invalid group name '#{group.inspect}'") unless group and group != ""
    end

    def insync?(current)
      # We don't want to validate/munge groups until we actually start to
      # evaluate this property, because they might be added during the catalog
      # apply.
      @should.map! do |val|
        provider.name2gid(val) or raise "Could not find group #{val}"
      end

      @should.include?(current)
    end

    # We want to print names, not numbers
    def is_to_s(currentvalue)
      provider.gid2name(currentvalue) || currentvalue
    end

    def should_to_s(newvalue)
      provider.gid2name(newvalue) || newvalue
    end
  end

  # Manage file modes.  This state should support different formats
  # for specification (e.g., u+rwx, or -0011), but for now only supports
  # specifying the full mode.
  newproperty(:mode) do
    require 'puppet/util/symbolic_file_mode'
    include Puppet::Util::SymbolicFileMode

    desc <<-EOT
      The desired permissions mode for the file, in symbolic or numeric
      notation. Puppet uses traditional Unix permission schemes and translates
      them to equivalent permissions for systems which represent permissions
      differently, including Windows.

      Numeric modes should use the standard four-digit octal notation of
      `<setuid/setgid/sticky><owner><group><other>` (e.g. 0644). Each of the
      "owner," "group," and "other" digits should be a sum of the
      permissions for that class of users, where read = 4, write = 2, and
      execute/search = 1. When setting numeric permissions for
      directories, Puppet sets the search permission wherever the read
      permission is set.

      Symbolic modes should be represented as a string of comma-separated
      permission clauses, in the form `<who><op><perm>`:

      * "Who" should be u (user), g (group), o (other), and/or a (all)
      * "Op" should be = (set exact permissions), + (add select permissions),
        or - (remove select permissions)
      * "Perm" should be one or more of:
          * r (read)
          * w (write)
          * x (execute/search)
          * t (sticky)
          * s (setuid/setgid)
          * X (execute/search if directory or if any one user can execute)
          * u (user's current permissions)
          * g (group's current permissions)
          * o (other's current permissions)

      Thus, mode `0664` could be represented symbolically as either `a=r,ug+w` or
      `ug=rw,o=r`. See the manual page for GNU or BSD `chmod` for more details
      on numeric and symbolic modes.

      On Windows, permissions are translated as follows:

      * Owner and group names are mapped to Windows SIDs
      * The "other" class of users maps to the "Everyone" SID
      * The read/write/execute permissions map to the `FILE_GENERIC_READ`,
        `FILE_GENERIC_WRITE`, and `FILE_GENERIC_EXECUTE` access rights; a
        file's owner always has the `FULL_CONTROL` right
      * "Other" users can't have any permissions a file's group lacks,
        and its group can't have any permissions its owner lacks; that is, 0644
        is an acceptable mode, but 0464 is not.
    EOT

    validate do |value|
      unless value.nil? or valid_symbolic_mode?(value)
        raise Puppet::Error, "The file mode specification is invalid: #{value.inspect}"
      end
    end

    munge do |value|
      return nil if value.nil?

      unless valid_symbolic_mode?(value)
        raise Puppet::Error, "The file mode specification is invalid: #{value.inspect}"
      end

      normalize_symbolic_mode(value)
    end

    def desired_mode_from_current(desired, current)
      current = current.to_i(8) if current.is_a? String
      is_a_directory = @resource.stat and @resource.stat.directory?
      symbolic_mode_to_int(desired, current, is_a_directory)
    end

    def property_matches?(current, desired)
      return false unless current
      current_bits = normalize_symbolic_mode(current)
      desired_bits = desired_mode_from_current(desired, current).to_s(8)
      current_bits == desired_bits
    end

    # Finally, when we sync the mode out we need to transform it; since we
    # don't have access to the calculated "desired" value here, or the
    # "current" value, only the "should" value we need to retrieve again.
    def sync
      current = @resource.stat ? @resource.stat.mode : 0644
      set(desired_mode_from_current(@should[0], current).to_s(8))
    end

    def change_to_s(old_value, desired)
      return super if desired =~ /^\d+$/

      old_bits = normalize_symbolic_mode(old_value)
      new_bits = normalize_symbolic_mode(desired_mode_from_current(desired, old_bits))
      super(old_bits, new_bits) + " (#{desired})"
    end

    def should_to_s(should_value)
      should_value.rjust(4, "0")
    end

    def is_to_s(currentvalue)
      currentvalue.rjust(4, "0")
    end
  end
  
  # Autorequire the nearest ancestor directory found in the catalog.
  autorequire(:file) do
    req = []
    path = Pathname.new(self[:path])
    if !path.root?
      # Start at our parent, to avoid autorequiring ourself
      parents = path.parent.enum_for(:ascend)
      if found = parents.find { |p| catalog.resource(:file, p.to_s) }
        req << found.to_s
      end
    end

    req
  end
  
  # Autorequire the owner and group of the file.
  {:user => :owner, :group => :group}.each do |type, property|
    autorequire(type) do
      if @parameters.include?(property)
        # The user/group property automatically converts to IDs
        next unless should = @parameters[property].shouldorig
        val = should[0]
        if val.is_a?(Integer) or val =~ /^\d+$/
          nil
        else
          val
        end
      end
    end
  end
  
  validate do
    unless self[:path]
      raise(Puppet::Error, "Path is a required attribute")
    end
  end

  def self.[](path)
    return nil unless path
    super(path.gsub(/\/+/, '/').sub(/\/$/, ''))
  end

  def self.instances
    return []
  end
  
  # Stat our directory.
  #
  # We use the initial value :needs_stat to ensure we only stat the file once,
  # but can also keep track of a failed stat (@stat == nil). This also allows
  # us to re-stat on demand by setting @stat = :needs_stat.
  def stat
    return @stat unless @stat == :needs_stat

    @stat = begin
      File.stat(self[:path])
    rescue Errno::ENOENT => error
      nil
    rescue Errno::EACCES => error
      warning "Could not stat; permission denied"
      nil
    end
  end  
      
end
