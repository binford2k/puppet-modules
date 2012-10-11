file { '/tmp/noxdir':
  ensure => directory,
}

noxdir { '/tmp/noxdir/test':
  owner => 'root',
  group => 'root',
  mode  => '0644',
}

noxdir { '/tmp/noxdir/test1':
  ensure => absent,
}

noxdir { '/tmp/noxdir/test2':
  owner => 'root',
  group => 'root',
  mode  => '0644',
}

noxdir { '/tmp/noxdir/test3':
  owner => 'joe',
  group => 'root',
  mode  => '0644',
}

noxdir::exec { '/tmp/noxdir/test4':
  owner => 'joe',
  group => 'root',
  mode  => '0644',
}

noxdir::exec { '/tmp/noxdir/test5':
  owner => 'root',
  mode  => '0644',
}

noxdir::exec { '/tmp/noxdir/test6':
  ensure => absent,
}

noxdir::exec { '/tmp/noxdir/test7':
  mode  => '0644',
}
