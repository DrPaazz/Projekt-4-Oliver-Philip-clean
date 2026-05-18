Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.ssh.insert_key = false

  config.vm.provider "virtualbox" do |vb|
    vb.memory = 1024
    vb.cpus = 1
  end

  config.vm.define "server" do |server|
    server.vm.hostname = "nfs-server"
    server.vm.network "private_network", ip: "192.168.56.10"
  end

  config.vm.define "client-a" do |client|
    client.vm.hostname = "client-a"
    client.vm.network "private_network", ip: "192.168.56.21"
  end

  config.vm.define "client-b" do |client|
    client.vm.hostname = "client-b"
    client.vm.network "private_network", ip: "192.168.56.22"
  end
end