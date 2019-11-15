# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/bionic64"
  config.ssh.forward_agent = true
  config.ssh.insert_key = true
  config.hostmanager.enabled = true

  config.trigger.before :up do |t|
    t.run = {path: "./scripts/keygen.sh"}
  end

  # worker node
  (1..2).each do |i|
    config.vm.define "k8s-worker-#{i}" do |config|
      config.vm.hostname = "k8s-worker-#{i}"
      config.vm.network :private_network, ip: "172.21.12.#{i+50}"
      config.vm.provision "file", source: ".keys/key_rsa.pub", destination: "authorized_keys"
      config.vm.provision :shell, :inline => "mkdir -p /root/.ssh && cp authorized_keys /root/.ssh/", :privileged => true
      config.vm.provision "shell", path: "scripts/install.sh", :privileged => true
    end
  end

  # master
  config.vm.define "k8s-master", primary: true do |config|
    config.vm.hostname = "k8s-master"
    config.vm.synced_folder ".", "/vagrant/"
    config.vm.network :private_network, ip: "172.21.12.50"
    config.vm.provider "virtualbox" do |v|
      v.memory = 3096
      v.cpus = 2
    end
    config.vm.provision "file", source: ".keys/key_rsa", destination: ".ssh/id_rsa"
    config.vm.provision "file", source: ".keys/key_rsa.pub", destination: ".ssh/id_rsa.pub"
    config.vm.provision "shell", path: "scripts/install.sh", :privileged => true
    config.vm.provision "shell", path: "scripts/init.sh", :privileged => true
  end
end
