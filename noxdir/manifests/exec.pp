# This is a sample define type to let you approximate a
# directory resource type without execute bit promotion.
# It is kludgy and fragile and not safe to use, because
# it is vulnerable to shell injection, intentional or not.
# It will also unconditionally run the exec statement on
# every single puppet run and clutter up your reports.
#
# Don't use it. This is for demonstration purposes only.
#
define noxdir::exec($ensure=present,
                    $owner=undef,
                    $group=undef,
                    $mode=undef) {

  if $mode == undef and $ensure != absent { fail('Mode is required.') }

  file { $name:
    ensure => $ensure ? {
      present => directory,
      default => absent,
    },
    owner => $owner,
    group => $group,
  }

  if $mode {
    exec { "/bin/chmod ${mode} ${name}":
      require => File[$name],
    }
  }
}