#
# Author:: Christian Trabold <christian.trabold@dkd.de>
# Cookbook Name:: redis
# Recipe:: package
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

package "redis-server"

service "redis" do
  supports :status => true, :restart => true, :reload => true
  action   :enable
  provider (platform?('ubuntu') && Chef::VersionConstraint.new('>= 15.04').include?(node['platform_version'])) ? Chef::Provider::Service::Systemd : nil
end

template "#{node[:redis][:config_path]}" do
  source "redis.conf.erb"
  owner "root"
  group "root"
  mode 0644

  notifies :restart, resources(:service => "redis"), :immediately
end
