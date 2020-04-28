# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/bionic64"
  config.vm.synced_folder ".", "/basedir/"
  config.vm.synced_folder "./assets", "/assets/"
  config.ssh.forward_agent = true
  config.ssh.insert_key = true
  config.hostmanager.enabled = true
  config.cache.scope = :box
  config.vm.provision :shell, :inline => "rm -rf /basedir/shared && mkdir -p /basedir/shared", :privileged => true

  config.trigger.before :up do |t|
    t.run = {path: "./scripts/keygen.sh"}
  end

  # worker node
  (1..2).each do |i|
    config.vm.define "k8s-worker-#{i}" do |config|
      config.vm.hostname = "k8s-worker-#{i}"
      config.vm.provider "virtualbox" do |v|
        v.memory = 2048
        v.cpus = 2
      end
      config.vm.network :private_network, ip: "172.21.12.#{i+50}"
      config.vm.provision "file", source: ".keys/key_rsa.pub", destination: "authorized_keys"
      config.vm.provision :shell, :inline => "mkdir -p /root/.ssh && cp authorized_keys /root/.ssh/", :privileged => true
      config.vm.provision "shell", path: "scripts/install-docker.sh", :privileged => true
      config.vm.provision "shell", path: "scripts/install-kube.sh", :privileged => true
    end
  end

  # master
  config.vm.define "k8s-master", primary: true do |config|
    config.vm.hostname = "k8s-master"
    config.vm.synced_folder ".", "/vagrant/"
    config.vm.network :private_network, ip: "172.21.12.50"
    config.vm.network "forwarded_port", guest: 80, host: 8080
    config.vm.network "forwarded_port", guest: 443, host: 8443
    config.vm.provider "virtualbox" do |v|
      v.memory = 2048
      v.cpus = 4
    end
    config.vm.provision "file", source: ".keys/key_rsa", destination: ".ssh/id_rsa"
    config.vm.provision "file", source: ".keys/key_rsa.pub", destination: ".ssh/id_rsa.pub"
    config.vm.provision "shell", path: "scripts/install-docker.sh", :privileged => true
    config.vm.provision "shell", path: "scripts/install-kube.sh", :privileged => true
    config.vm.provision "shell", path: "scripts/init.sh", :privileged => true
  end
end
