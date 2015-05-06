# -*- mode: ruby -*-
# vi: set ft=ruby :

# Use YAML for Vagrant configuration
require 'yaml'

dir        = File.dirname(File.expand_path(__FILE__))
configFile = File.join(dir, 'config.yaml')

if File.exists?(configFile) then
  conf = YAML.load_file(configFile)
else
  puts 'Missing configuration: ' + configFile
  exit 1
end

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = conf['vm']['box']

  if conf['vm']['nfs']
    config.vm.network :private_network, ip: conf['vm']['ip_address']
  end

  config.vm.network :forwarded_port, guest: 80, host: conf['vm']['port']

  # Configuration Files (i.e. this project).
  config.vm.synced_folder '.', '/conf', nfs: conf['vm']['nfs']

  # Path to your vindinium-hacklang project (maps to /vagrant in the guest).
  if conf['project']
    config.vm.synced_folder conf['project'], '/vagrant', nfs: conf['vm']['nfs']
  end

  config.vm.provider "virtualbox" do |vb|
    host = RbConfig::CONFIG['host_os']

    # Give VM 1/4 system memory & access to all cpu cores on the host
    # @see http://www.stefanwrobel.com/how-to-make-vagrant-performance-not-suck
    if host =~ /darwin/
      cpus = `sysctl -n hw.ncpu`.to_i
      # sysctl returns Bytes and we need to convert to MB
      mem = `sysctl -n hw.memsize`.to_i / 1024 / 1024 / 4
    elsif host =~ /linux/
      cpus = `nproc`.to_i
      # meminfo shows KB and we need to convert to MB
      mem = `grep 'MemTotal' /proc/meminfo | sed -e 's/MemTotal://' -e 's/ kB//'`.to_i / 1024 / 4
    else # sorry Windows folks, I can't help you
      cpus = 2
      mem = 1024
    end

    vb.customize ['modifyvm', :id, '--memory', mem]
    vb.customize ['modifyvm', :id, '--cpus', cpus]
  end

  if Vagrant.has_plugin?('vagrant-librarian-puppet')
    config.librarian_puppet.puppetfile_dir        = 'puppet'
    config.librarian_puppet.placeholder_filename  = '.gitignore'
  end

  config.vm.provision 'puppet' do |puppet|
    puppet.facter = {
      'fqdn'             => conf['server']['domain'],
      'ssh_username'     => 'vagrant',
      'provisioner_type' => ENV['VAGRANT_DEFAULT_PROVIDER'],
    }
    puppet.manifests_path     = 'puppet'
    puppet.module_path        = 'puppet/modules'
    puppet.hiera_config_path  = 'puppet/hiera.yaml'
    puppet.options            = [ '--parser=future' ]
  end

  config.ssh.forward_agent = true
end
