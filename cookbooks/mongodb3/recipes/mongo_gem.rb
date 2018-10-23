# install the mongo ruby gem at compile time to make it globally available
gem_package 'aws-sdk' do
  action :nothing
end.run_action(:install)
Chef::Log.warn("Installing AWS SDK")
chef_gem 'mongo' do
  action :install
end
Chef::Log.warn("Installing mongo")
chef_gem 'bson_ext' do
  action :install
end
Chef::Log.warn("Installing BSON")
