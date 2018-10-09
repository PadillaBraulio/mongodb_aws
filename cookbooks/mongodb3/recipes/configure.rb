# Configure replicas
this_instance = search("aws_opsworks_instance", "self:true").first
layer_id      = this_instance["layer_ids"][0]
mongo_nodes = []
search("aws_opsworks_instance", "layer_ids:#{layer_id}").each do |instance|
  mongo_nodes.push(instance['hostname'])
end

# TODO Get the node status, and exist until they all are in online state
ruby_block 'configure_replicas' do
  block do
    if this_instance["hostname"] == "#{node['master_node']}"
      sleep(180)
      system("echo \"rs.initiate()\" | mongo")
      mongo_nodes.each do |host|
        if host != this_instance["hostname"]
          system("echo \"rs.add('#{host}:27017')\" | mongo")
        end
      end
    end
  end
end
