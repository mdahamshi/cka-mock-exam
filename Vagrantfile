# -*- mode: ruby -*-
# vi:set ft=ruby sw=2 ts=2 sts=2:

BUILD_MODE = "BRIDGE"
NUM_WORKER_NODES = 2

IP_NW = "192.168.56"
MASTER_IP_START = 11
NODE_IP_START = 20

# Detect bridge adapter (your real NIC)
def get_bridge_adapter()
  %x{ip route | grep default | awk '{ print $5 }'}.chomp
end

# Check if a VM exists via virsh instead of VirtualBox
def get_machine_id(vm_name)
  result = %x{virsh dominfo #{vm_name} 2>/dev/null}.chomp
  result.empty? ? nil : vm_name
end

def all_nodes_up()
  return false if get_machine_id("controlplane").nil?
  (1..NUM_WORKER_NODES).each do |i|
    return false if get_machine_id("node0#{i}").nil?
  end
  true
end

def setup_dns(node)
  node.vm.provision "setup-hosts", :type => "shell", :path => "ubuntu/vagrant/setup-hosts.sh" do |s|
    s.args = [IP_NW, BUILD_MODE, NUM_WORKER_NODES, MASTER_IP_START, NODE_IP_START]
  end
  node.vm.provision "setup-dns", type: "shell", :path => "ubuntu/update-dns.sh"
end

def provision_kubernetes_node(node)
  setup_dns node
  node.vm.provision "setup-ssh", :type => "shell", :path => "ubuntu/ssh.sh"
end

Vagrant.configure("2") do |config|
  config.vm.box = "generic/ubuntu2204"   # libvirt-compatible box
  config.vm.boot_timeout = 900
  config.vm.box_check_update = false

  # Controlplane
  config.vm.define "controlplane" do |node|
    node.vm.hostname = "controlplane"

    node.vm.provider :libvirt do |lv|
      lv.driver = "kvm"
      lv.memory = 2048
      lv.cpus   = 2
    end

    if BUILD_MODE == "BRIDGE"
      node.vm.network :public_network,
        :dev  => get_bridge_adapter(),
        :mode => "bridge",
        :type => "bridge"
    else
      node.vm.network :private_network, ip: "#{IP_NW}.#{MASTER_IP_START}"
    end

    provision_kubernetes_node node
    node.vm.provision "file", source: "./ubuntu/tmux.conf", destination: "$HOME/.tmux.conf"
    node.vm.provision "file", source: "./ubuntu/vimrc",    destination: "$HOME/.vimrc"
  end

  # Worker nodes
  (1..NUM_WORKER_NODES).each do |i|
    config.vm.define "node0#{i}" do |node|
      node.vm.hostname = "node0#{i}"

      node.vm.provider :libvirt do |lv|
        lv.driver = "kvm"
        lv.memory = 2048
        lv.cpus   = 2
      end

      if BUILD_MODE == "BRIDGE"
        node.vm.network :public_network,
          :dev  => get_bridge_adapter(),
          :mode => "bridge",
          :type => "bridge"
      else
        node.vm.network :private_network, ip: "#{IP_NW}.#{NODE_IP_START + i}"
      end

      provision_kubernetes_node node
    end
  end

  # Post-up trigger (BRIDGE mode only)
  if BUILD_MODE == "BRIDGE"
    config.trigger.after :up do |trigger|
      trigger.name = "Post provisioner"
      trigger.ignore = [:destroy, :halt]
      trigger.ruby do |env, machine|
        if all_nodes_up()
          puts "    Gathering IP addresses of nodes..."
          nodes = ["controlplane"] + (1..NUM_WORKER_NODES).map { |i| "node0#{i}" }
          ips   = nodes.map { |n| %x{vagrant ssh #{n} -c 'public-ip'}.chomp }

          hosts = ips.each_with_index.map { |ip, i| "#{ip}  #{nodes[i]}" }.join("\n")

          puts "    Setting /etc/hosts on nodes..."
          File.write("hosts.tmp", hosts)
          nodes.each do |n|
            system("vagrant upload hosts.tmp /tmp/hosts.tmp #{n}")
            system("vagrant ssh #{n} -c 'cat /tmp/hosts.tmp | sudo tee -a /etc/hosts'")
          end
          File.delete("hosts.tmp")

          puts "\n  VM build complete!\n\n"
          (1..NUM_WORKER_NODES).each { |i| puts "  http://#{ips[i]}:port_number" }
          puts ""
        else
          puts "    Nothing to do here"
        end
      end
    end
  end
end