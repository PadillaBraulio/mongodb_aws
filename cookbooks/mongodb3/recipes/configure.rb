package 'awscli'
# Configure replicas
this_instance             = search("aws_opsworks_instance", "self:true").first
layer_id                  = this_instance["layer_ids"][0]
# availability_zone         = this_instance["availability_zone"]
# n = availability_zone.size
# region=availability_zone[0..n-2]
mongo_nodes = []
search("aws_opsworks_instance", "layer_ids:#{layer_id}").each do |instance|
  mongo_nodes.push(instance['hostname'])
end

# TODO Get the node status, and exist until they all are in online state
ruby_block 'configure_replicas' do
  block do
    if "#{node['is_initiated']}" == "no"
      Chef::Log.info "Initializing replica set"
      system("echo \"rs.initiate()\" | mongo")
      system("aws opsworks --region us-east-1 update-layer --layer-id #{layer_id} --custom-json " + '"{\"is_initiated\":\"yes\"}"' )
    end
    mongo_nodes.each do |host|
      Chef::Log.info "Adding nodes"
      if host != this_instance["hostname"]
        system("echo \"rs.add('#{host}:27017')\" | mongo")
      end
    end
  end
end
