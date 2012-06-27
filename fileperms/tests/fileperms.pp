fileperms { '/etc/motd':
  ensure => present,
  perms  => '0640',
}

fileperms { 'sudoers':
  ensure => present,
  path   => '/etc/sudoers',
  perms  => '0600',
}
