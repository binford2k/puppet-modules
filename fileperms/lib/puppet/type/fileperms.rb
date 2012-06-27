Puppet::Type.newtype(:fileperms) do

  desc <<-EOT
    Ensures that a file meets maximum permission constraints.

    Example:

        fileperms { 'sudoers':
          ensure => present,
          path   => '/etc/sudoers',
          perms  => '0640',
        }

  EOT

  ensurable

  newparam(:path, :namevar => true) do
    desc 'File to check permissions of.'
    validate do |value|
      unless (Puppet.features.posix? and value =~ /^\//) or (Puppet.features.microsoft_windows? and (value =~ /^.:\// or value =~ /^\/\/[^\/]+\/[^\/]+/))
        raise(Puppet::Error, "File paths must be fully qualified, not '#{value}'")
      end
    end
  end

  newparam(:perms) do
    desc 'The maximum permissions allowable.'
  end

  validate do
    unless self[:perms] and self[:path]
      raise(Puppet::Error, "Both path and perms are required attributes")
    end
  end
end
