# -*- mode: ruby -*-
# vi: set ft=ruby :
#config.vm.network :forwarded_port, guest: 22, host: 2222, adapter: 1

Vagrant.configure("2") do |config|

  # Main controller machine
  config.vm.define :chaos do |chaos|
    chaos.vm.box = "precise64"
    chaos.vm.box_url = "http://files.vagrantup.com/precise64.box"
    chaos.vm.network :private_network, ip: "192.168.60.1"
    chaos.vm.synced_folder "./", "/home/vagrant/chaos"
    if Dir.exist? "../chaos-chef-repo"
      chaos.vm.synced_folder "../chaos-chef-repo", "/var/lib/chaos/chaos-chef-repo"
    end
    chaos.vm.provision :shell, path: "vendor/vagrant/bootstrap.sh"
  end

  # Testing machines - Debian Squeeze (v6) - x86_64
  config.vm.define :debian do |debian|
    debian.vm.box = "squeeze64"
    debian.vm.box_url = "http://dl.dropbox.com/u/54390273/vagrantboxes/Squeeze64_VirtualBox4.2.4.box"
    debian.vm.network :private_network, ip: "192.168.60.2"
  end
end
