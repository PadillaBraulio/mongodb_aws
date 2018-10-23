package 'awscli'
include_recipe "mongodb3::mongo_gem"

require 'json'
require 'mongo'
require 'bson'
require "aws-sdk-opsworks"

# Obtaning mongo instnaces
this_instance = search("aws_opsworks_instance", "self:true").first
layer_id = this_instance["layer_ids"][0]
mongo = Mongo::Client.new([ '127.0.0.1' ], :database => "admin", :connect => "direct", :server_selection_timeout => 5)
opsworks = Aws::OpsWorks::Client.new(:region => "us-east-1")

rs_members = []
rs_member_ips = []
mongo_nodes = []
i = 0
configured = true

search("aws_opsworks_instance", "layer_ids:#{layer_id}").each do |instance|
  i += 1
  rs_members << {"_id" => i, "host" => "#{instance['hostname']}"}
  rs_member_ips << {"_id" => i, "host" => "#{instance['ipaddress']}"}
  mongo_nodes.push(instance['hostname'])
end

ruby_block 'Configuring_replica_set' do
  block do
    Chef::Log.info "Checking configuration"
    config = {}
    config['replSetGetConfig'] = 1

    init_hosts = []
    mongo_nodes.each do |host|
      begin
        check = Mongo::Client.new([ "#{host}" ], :database => "admin", :connect => "direct", :server_selection_timeout => 5)
        check.database.command(config)
        Chef::Log.info "Configuration found"
        init_hosts.push(true)
      rescue Mongo::Auth::Unauthorized, Mongo::Error => e
        info_string  = "Error #{e.class}: #{e.message}"
        Chef::Log.info "No configuration found: " + info_string
        init_hosts.push(false)
      end
    end

    Chef::Log.info "Configuration found: " + init_hosts.join(", ")

    unless init_hosts.include?(true)
      configured = false
    end

    unless configured
      master_node_command = opsworks.describe_instances({
        layer_id: layer_id,
      })
      master_node= master_node_command.instances[0].hostname
      Chef::Log.info "Checking hostname " + master_node
      if master_node == this_instance["hostname"]
        Chef::Log.info "Initializing replica set"
        cmd = {}
        cmd['replSetInitiate'] = {
            "_id" => "#{node['mongodb3']['config']['mongod']['replication']['replSetName']}",
            "members" => rs_members
        }
        begin
          mongo.database.command(cmd)
        rescue Mongo::Auth::Unauthorized, Mongo::Error => e
          info_string  = "Error #{e.class}: #{e.message}"
          Chef::Log.info "Initialization failed: " + info_string
        end
      end
    end

  end
end


ruby_block 'Adding and removing members' do
  block do
    if configured
      cmd = {}
      cmd['replSetGetStatus'] = 1
      status = mongo.database.command(cmd)
      config = {}
      config['replSetGetConfig'] = 1
      config = mongo.database.command(config)
      version = config.documents[0]["config"]["version"].to_i
      Chef::Log.info "Configuration version: " + version.to_s
      state = status.documents[0]

      if state["myState"].to_i == 1
        sleep(120)
        Chef::Log.info "Master member, state: " + state["myState"].to_s
        Chef::Log.info "Cluster size: " + state["members"].size.to_s
        rs_new_members = []
        members = []
        health = true
        i = 0
        for member in state["members"] do
          members.push("#{member["name"]}")
          if member["state"].to_i != 1 && member["health"].to_i == 0
            Chef::Log.info "Member unhealthy, deleting: " + member["name"].to_s
            health = false
          else
            i += 1
            Chef::Log.info "Member healthy, skipping: " + member["name"].to_s
            rs_new_members << {"_id" => i, "host" => "#{member["name"]}"}
          end
        end

        Chef::Log.info "Checking for new members"
        mongo_nodes.each do |host|
          host_name = "#{host}:27017"
          unless members.include?(host_name)
            i += 1
            available = true
            Chef::Log.info "New member found, checking availability: " + host_name
            begin
              check = Mongo::Client.new([ "#{host}" ], :database => "admin", :connect => "direct", :server_selection_timeout => 5)
              check.database_names
            rescue Mongo::Auth::Unauthorized, Mongo::Error => e
              available = false
              info_string  = "Error #{e.class}: #{e.message}"
              Chef::Log.info "Member Unavailable: " + info_string
            end

            if available
              rs_new_members << {"_id" => i, "host" => host_name}
              Chef::Log.info "New member added: " + host_name
              health = false
            end
          end
        end

        if health
          Chef::Log.info "Cluster healthy, no reconfiguration needed"
        else
          Chef::Log.info "Cluster unhealthy, reconfiguration needed"
          new_version = version + 1
          Chef::Log.info "New configuration version: " + new_version.to_s
          cmd = {}
          cmd['replSetReconfig'] = {
            "version" => new_version,
            "_id" => "#{node['mongodb3']['config']['mongod']['replication']['replSetName']}",
            "members" => rs_new_members
          }
          begin
            mongo.database.command(cmd)
          rescue Mongo::Auth::Unauthorized, Mongo::Error => e
            info_string  = "Error #{e.class}: #{e.message}"
            Chef::Log.info "Re-Initialization failed: " + info_string
          end
        end

      end
    end
  end
end
