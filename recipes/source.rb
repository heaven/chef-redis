#
# Author:: Christian Trabold <christian.trabold@dkd.de>
# Author:: Fletcher Nichol <fnichol@nichol.ca>
# Cookbook Name:: redis
# Recipe:: source
#
# Copyright 2011, dkd Internet Service GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

cache_dir       = Chef::Config[:file_cache_path]
install_prefix  = node['redis']['source']['prefix']
tar_url         = node['redis']['source']['tar_url']
tar_checksum    = node['redis']['source']['tar_checksum']
tar_file        = "redis-#{node['redis']['source']['version']}.tar.gz"
tar_dir         = tar_file.sub(/\.tar\.gz$/, '')
port            = node['redis']['port']
redis_user      = node['redis']['source']['user']
redis_group     = node['redis']['source']['group']

Array(node['redis']['source']['pkgs']).each { |pkg| package pkg }

remote_file "#{cache_dir}/#{tar_file}" do
  source    tar_url
  checksum  tar_checksum
  mode      "0644"
end

execute "Extract #{tar_file}" do
  cwd       cache_dir
  command   <<-COMMAND
    rm -rf #{tar_dir} && \
    mkdir #{tar_dir} && \
    tar zxf #{tar_file} -C #{tar_dir} --strip-components 1
  COMMAND

  creates   "#{cache_dir}/#{tar_dir}/utils/redis_init_script"
end

execute "Build #{tar_dir.split('/').last}" do
  cwd       "#{cache_dir}/#{tar_dir}"
  command   %{make prefix=#{install_prefix} install}

  creates   "#{install_prefix}/bin/redis-server"
end

group redis_group

user redis_user do
  gid redis_group
  home    node[:redis][:dir]
  system  true
end

[node[:redis][:dir], File.dirname(node[:redis][:config_path]), File.dirname(node[:redis][:logfile]), File.dirname(node[:redis][:pidfile])].each do |dir|
  directory dir do
    owner       redis_user
    group       redis_group
    mode        "0755"
    recursive   true
    not_if { ::File.exists?(dir) }
  end
end

if node['redis']['source']['create_service']
  node.set['redis']['daemonize']      =   "yes"
  
  if platform?('ubuntu') && Chef::VersionConstraint.new('>= 15.04').include?(node['platform_version'])
    node.set['redis']['supervised']   =   "systemd"
    
    template "/etc/systemd/system/redis.service" do
      source 'systemd/redis.service.erb'
      owner 'root'
      group 'root'
      mode 0644
      notifies :run, 'execute[systemctl daemon-reload]', :immediately
    end

    execute 'systemctl daemon-reload' do
      action :nothing
    end
  else
    template "/etc/init.d/redis" do
      source  "init/init.sh.erb"
      owner   "root"
      group   "root"
      mode    "0755"
    end
  end
  
  service "redis" do
    supports :status => true, :restart => true, :reload => true
    action   :enable
    provider (platform?('ubuntu') && Chef::VersionConstraint.new('>= 15.04').include?(node['platform_version'])) ? Chef::Provider::Service::Systemd : nil
  end

  directory File.dirname("#{node[:redis][:config_path]}") do
    owner   "root"
    group   "root"
    mode    "0755"
    recursive true
  end

  template "#{node[:redis][:config_path]}" do
    source  "redis.conf.erb"
    owner   "root"
    group   "root"
    mode    "0644"

    notifies :restart, resources(:service => "redis"), :immediately
  end
end
