require 'puppet'
require 'yaml'

Puppet::Reports.register_report(:resource_statuses) do

  desc <<-DESC
  Write out a YAML file with the status of every resource we are enforcing.
  DESC

  # process one report as the `self` object
  def process

    # open our output file. Will be cleaned up when we exit the do/end block
    File.open('/tmp/resource_statuses.yaml', 'w') do |f|
      # define a collector hash
      stats = {}

      # loop over each resource status
      self.resource_statuses.each do |rname, resource|

        # decide what our status should be
        if resource.out_of_sync_count == 0
          # Nothing was out of sync
          status = 'Up to date'
        elsif resource.out_of_sync_count == resource.change_count
          # Things were out of sync, but we successfully updated each of them
          status = 'Updated'
        else
          status = 'Failed'
        end

        # add an entry to our stats collector
        stats[rname] = {
          'title'  => resource.title,
          'status' => status,
          'tags'   => resource.tags
        }
      end

      # write out the stats object in yaml format
      f.puts stats.to_yaml
    end
  end
end

