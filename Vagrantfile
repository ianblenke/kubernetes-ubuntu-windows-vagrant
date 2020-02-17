# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.require_version ">= 1.8.4"

# to make sure the km1 node is created before the other nodes, we
# have to force a --no-parallel execution.
ENV['VAGRANT_NO_PARALLEL'] = 'yes'

require 'ipaddr'

number_of_master_nodes          = 1
number_of_ubuntu_worker_nodes   = 3
number_of_windows_worker_nodes  = 1
first_master_node_ip            = '10.11.0.101'
first_ubuntu_worker_node_ip     = '10.11.0.201'
first_windows_worker_node_ip    = '10.11.0.221'
pod_network_cidr                = '10.12.0.0/16'
service_cidr                    = '10.13.0.0/16'  # default is 10.96.0.0/12
kube_dns_service_ip             = '10.13.0.10'    # this is normally at .10 (use kubectl -n kube-system get service/kube-dns to really known)
service_dns_domain              = 'cluster.local' # NB do not change this default because the ms windows scripts have this hardcoded (default is cluster.local)
master_node_ip_addr             = IPAddr.new first_master_node_ip
ubuntu_worker_node_ip_addr      = IPAddr.new first_ubuntu_worker_node_ip
windows_worker_node_ip_addr     = IPAddr.new first_windows_worker_node_ip

Vagrant.configure(2) do |config|
  config.vm.box = 'ubuntu/xenial64'

  config.vm.provider 'libvirt' do |lv, config|
    lv.cpus = 4
    lv.cpu_mode = 'host-passthrough'
    lv.nested = true
    lv.keymap = 'pt'
    config.vm.synced_folder '.', '/vagrant', type: 'nfs'
  end

  config.vm.provider 'virtualbox' do |vb|
    config.vagrant.plugins = [ "vagrant-disksize" ]
    vb.linked_clone = true
    vb.cpus = 4
  end

  (1..number_of_master_nodes).each do |n|
    name = "km#{n}"
    fqdn = "#{name}.example.test"
    ip = master_node_ip_addr.to_s; master_node_ip_addr = master_node_ip_addr.succ

    config.vm.define name do |config|
      config.vm.network "forwarded_port", guest: 6443, host: 6443-1+n, protocol: "tcp", auto_correct: true, id: "#{name}kubeapi"
      # NB 512M of memory is not enough to run a kubernetes master.
      config.vm.provider 'libvirt' do |lv, config|
        lv.memory = 1024
      end
      config.vm.provider 'virtualbox' do |vb|
        vb.memory = 1024
      end
      config.vm.hostname = fqdn
      config.vm.network :private_network, ip: ip, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false
      config.vm.provision 'shell', path: 'provision-base.sh', args: ['master']
      config.vm.provision 'shell', path: 'provision-docker.sh'
      config.vm.provision 'shell', path: 'provision-kubernetes-tools.sh', args: [ip]
      config.vm.provision 'shell', path: 'provision-kubernetes-master.sh', args: [ip, pod_network_cidr, service_cidr, service_dns_domain]
    end
  end

  (1..number_of_ubuntu_worker_nodes).each do |n|
    name = "kwu#{n}"
    fqdn = "#{name}.example.test"
    ip = ubuntu_worker_node_ip_addr.to_s; ubuntu_worker_node_ip_addr = ubuntu_worker_node_ip_addr.succ

    config.vm.define name do |config|
      config.vm.network "forwarded_port", guest: 80, host: 80-1+n, protocol: "tcp", auto_correct: true, id: "#{name}http"
      config.vm.network "forwarded_port", guest: 443, host: 443-1+n, protocol: "tcp", auto_correct: true, id: "#{name}https"
      config.vm.network "forwarded_port", guest: 1433, host: 1433-1+n, protocol: "tcp", auto_correct: true, id: "#{name}mssql"
      config.vm.provider 'libvirt' do |lv, config|
        lv.memory = 12*1024
      end
      config.vm.provider 'virtualbox' do |vb|
        vb.memory = 12*1024
        config.vagrant.plugins = [ "vagrant-disksize" ]
        config.disksize.size = '100GB'
      end
      config.vm.hostname = fqdn
      config.vm.network :private_network, ip: ip, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false
      config.vm.provision 'shell', path: 'provision-base.sh', args: ['worker']
      config.vm.provision 'shell', path: 'provision-docker.sh'
      config.vm.provision 'shell', path: 'provision-kubernetes-tools.sh', args: [ip]
      config.vm.provision 'shell', path: 'provision-kubernetes-worker.sh'
    end
  end

  (1..number_of_windows_worker_nodes).each do |n|
    name = "kww#{n}"
    ip = windows_worker_node_ip_addr.to_s; windows_worker_node_ip_addr = windows_worker_node_ip_addr.succ

    config.vm.define name do |config|
      config.vm.box = 'StefanScherer/windows_2019'
      config.vm.provider 'libvirt' do |lv, config|
        lv.memory = 4*1024
        # replace the default synced_folder with something that works in the base box.
        # NB for some reason, this does not work when placed in the base box Vagrantfile.
        config.vm.synced_folder ".", "/vagrant", type: "smb", smb_username: ENV["USER"], smb_password: ENV["VAGRANT_SMB_PASSWORD"]
      end
      config.vm.provider 'virtualbox' do |vb|
        vb.memory = 4*1024
        config.vagrant.plugins = [ "vagrant-disksize" ]
        config.disksize.size = '100GB'
      end
      config.winrm.username = 'vagrant\vagrant'
      config.vm.hostname = name
      config.vm.network :private_network, ip: ip, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false
      config.vm.provision 'shell', path: 'windows/ps.ps1', args: 'provision-containers-feature.ps1', privileged: false
      config.vm.provision 'shell', inline: 'echo "Rebooting..."', reboot: true, privileged: false
      config.vm.provision 'shell', path: 'windows/ps.ps1', args: 'provision-chocolatey.ps1', privileged: false
      config.vm.provision 'shell', path: 'windows/ps.ps1', args: 'provision-base.ps1', privileged: false
      #config.vm.provision 'shell', path: 'windows/ps.ps1', args: 'provision-ssh.ps1', privileged: false
      config.vm.provision 'shell', path: 'windows/ps.ps1', args: 'provision-docker.ps1', privileged: false
      config.vm.provision 'shell', path: 'windows/ps.ps1', args: 'provision-docker-reg.ps1', privileged: false
      config.vm.provision 'shell', path: 'windows/provision-docker-prepare-network.ps1', reboot: true, privileged: false
      config.vm.provision 'shell', path: 'windows/ps.ps1', args: ['provision-kubernetes-worker.ps1', ip, pod_network_cidr, service_cidr, service_dns_domain, kube_dns_service_ip], privileged: false
      config.vm.provision 'shell', inline: 'echo "Rebooting..."', reboot: true, privileged: false
    end
  end
end
