def find_provider
  if Chef::VersionConstraint.new('>= 15.04').include?(node['platform_version'])
    service_provider = Chef::Provider::Service::Systemd
  # No support for upstart - rely on init script for Ubuntu < 15.04
  #elsif Chef::VersionConstraint.new('>= 12.04').include?(node['platform_version'])
    #service_provider = Chef::Provider::Service::Upstart
  else
    service_provider = nil
  end
  service_provider
end