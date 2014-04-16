# Encoding: utf-8
#
# Cookbook Name:: logstash
# Recipe:: default
#
include_recipe 'runit' unless node['platform_version'] >= '12.04'

cookbook_file "/etc/default/logstash" do
  source "default_logstash"
  owner "root"
  group "root"
  mode "0644"
end

config_dir = "#{node['logstash']['server']['config_dir']}"

if node['logstash']['server']['install_method'] == 'repo'
  service_resource = 'service[logstash]'
  node.set['logstash']['server']['patterns_dir'] = '/etc/logstash/patterns'
  config_dir = "#{node['logstash']['server']['config_dir']}"
elsif node['logstash']['server']['init_method'] == 'runit'
  include_recipe 'runit'
  service_resource = 'runit_service[logstash_server]'
else
  service_resource = 'service[logstash_server]'
end

if node['logstash']['server']['patterns_dir'][0] == '/'
  patterns_dir = node['logstash']['server']['patterns_dir']
else
  patterns_dir = node['logstash']['server']['home'] + '/' + node['logstash']['server']['patterns_dir']
end

directory patterns_dir do
  action :create
  mode '0755'
  owner node['logstash']['user']
  group node['logstash']['group']
end

node['logstash']['patterns'].each do |file, hash|
  template_name = patterns_dir + '/' + file
  template template_name do
    source 'patterns.erb'
    owner node['logstash']['user']
    group node['logstash']['group']
    variables(:patterns => hash)
    mode '0644'
    notifies :restart, service_resource
  end
end

if node['logstash']['create_account']

  group node['logstash']['group'] do
    system true
    gid node['logstash']['gid']
  end

  user node['logstash']['user'] do
    group node['logstash']['group']
    home node['logstash']['homedir']
    system true
    action :create
    manage_home true
    uid node['logstash']['uid']
  end

else
  directory node['logstash']['homedir'] do
    recursive true
    action :create
    group node['logstash']['group']
    owner node['logstash']['user']
    mode '0755'
  end
end

directory node['logstash']['basedir'] do
  action :create
  owner 'root'
  group 'root'
  mode '0755'
end

node['logstash']['join_groups'].each do |grp|
  group grp do
    members node['logstash']['user']
    action :modify
    append true
    only_if "grep -q '^#{grp}:' /etc/group"
  end
end
