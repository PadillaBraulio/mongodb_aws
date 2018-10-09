require 'spec_helper'

# RHEL and Debian family has different value for some of mongodb settings.
if os[:family] == 'redhat'
  mongo_user = 'mongod'
elsif ['debian', 'ubuntu']
  mongo_user = 'mongodb'
end

mongo_data_dir = '/var/lib/mongodb/custom'
mongo_syslog_path = '/var/log/mongodb/custom/mongod.log'

# Test `mongodb-org-server` package is installed.
describe package('mongodb-org-server') do
  it { should be_installed }
end

# Test `mongod` service is running.
describe service('mongod') do
  it { should be_enabled }
  it { should be_running }
end

# Test mongodb port `27017` is listening.
describe port(27017) do
  it { should be_listening }
end

# Test mongod process starts with expected mongodb config file
describe command('ps -ef | grep mongod') do
  its(:stdout) { should contain('/etc/mongod.conf') }
end

# Test mongodb config file is created with right permission.
describe file('/etc/mongod.conf') do
  it { should be_file }
  it { should be_owned_by 'root' }
  it { should be_grouped_into 'root' }
end

# Test mongodb data directory is created with right permission.
describe file(mongo_data_dir) do
  it { should be_directory }
  it { should be_mode 755 }
  it { should be_owned_by mongo_user }
  it { should be_grouped_into mongo_user }
end

# Test mongodb log file is created with right permission.
describe file(mongo_syslog_path) do
  it { should be_file }
  it { should be_owned_by mongo_user }
end

# Test mongod process starts with expected mongodb config file
describe command('export LC_ALL="en_US.UTF-8"; mongo --eval "db.version()"') do
  its(:stdout) { should contain('3.2.8') }
end
