define variables::notify {
  notify { $name:
    message => template('variables/scope.erb'),
  }
}