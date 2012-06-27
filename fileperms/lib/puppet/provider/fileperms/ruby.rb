Puppet::Type.type(:fileperms).provide(:ruby) do

  # if this returns false, then attempt to create the resource
  def exists?
    # get only the lower bits of the file's mode
    filemode = File.stat(resource[:path]).mode ^ 0100000
    maxmode = resource[:perms].to_i(8)

    # if this is nonzero, then filemode has permissions not in maxmode
    ((filemode ^ maxmode) & filemode) == 0
  end

  # creation always fails, because we just want to flag noncompliance
  def create
    #raise(Puppet::Error, "Overly permissive permissions detected!")
    warning("Overly permissive permissions detected!")
  end

  def destroy
    # noop
  end

end
