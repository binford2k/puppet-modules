define variables::file (
  $owner = undef,
  $group = undef,
  $mode  = undef
) {
  file { $name:
    ensure  => file,
    owner => $owner,
    group => $group,
    mode  => $mode,
    content => template('variables/scope.erb'),
  }
}