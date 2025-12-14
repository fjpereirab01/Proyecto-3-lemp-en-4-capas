# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "debian/bookworm64"

  config.vm.define "balanceadorFJ" do |balanceadorFJ|
    balanceadorFJ.vm.hostname = "balanceadorFJ"
    balanceadorFJ.vm.network "private_network", ip: "192.168.10.10"
    balanceadorFJ.vm.network "private_network", ip: "192.168.20.30"
    balanceadorFJ.vm.network "forwarded_port", guest: 80, host: 8080
    balanceadorFJ.vm.provision "shell", path: "aprovisionamiento/bl.sh"
  end
    config.vm.define "serverweb1FJ" do |web1FJ|
    web1FJ.vm.hostname = "serverweb1FJ"
    web1FJ.vm.network "private_network", ip: "192.168.20.20"
    web1FJ.vm.provision "shell", path: "aprovisionamiento/web.sh"
  end
    config.vm.define "serverweb2FJ" do |web2FJ|
    web2FJ.vm.hostname = "serverweb2FJ"
    web2FJ.vm.network "private_network", ip: "192.168.20.30"
    web2FJ.vm.provision "shell", path: "aprovisionamiento/web2.sh"
  end
    config.vm.define "serverNFSFJ" do |serverNFSFJ|
    serverNFSFJ.vm.hostname = "serverNFSFJ"
    serverNFSFJ.vm.network "private_network", ip: "192.168.20.10"
    serverNFSFJ.vm.network "private_network", ip: "192.168.30.20"
    serverNFSFJ.vm.provision "shell", path: "aprovisionamiento/nfs.sh"
  end
    config.vm.define "proxyBDFJ" do |proxyBDFJ|
    proxyBDFJ.vm.hostname = "proxyBDFJ"
    proxyBDFJ.vm.network "private_network", ip: "192.168.30.10"
    proxyBDFJ.vm.network "private_network", ip: "192.168.40.10"
    proxyBDFJ.vm.provision "shell", path: "aprovisionamiento/proxybd.sh"
  end
    config.vm.define "db2FJ" do |db2FJ|
    db2FJ.vm.hostname = "db2FJ"
    db2FJ.vm.network "private_network", ip: "192.168.40.30"
    db2FJ.vm.provision "shell", path: "aprovisionamiento/bd2.sh"
  end
  config.vm.define "db1FJ" do |db1FJ|
    db1FJ.vm.hostname = "db1FJ"
    db1FJ.vm.network "private_network", ip: "192.168.40.20"
    db1FJ.vm.provision "shell", path: "aprovisionamiento/bd.sh"
  end
end