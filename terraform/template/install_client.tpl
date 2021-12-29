#!/bin/bash
# curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
# sudo apt-add-repository 'deb [arch=amd64] https://apt.releases.hashicorp.com bionic main'
# sudo apt-get update && sudo apt-get -y install consul nomad vault netcat

# sudo apt-get install -y \
#     apt-transport-https \
#     ca-certificates \
#     curl \
#     gnupg \
#     lsb-release

# sudo apt-get update
# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
# sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"

# sudo apt-get update
# sudo apt-get install -y docker-ce openjdk-11-jdk

sudo cat <<EOCONFIG > /etc/consul.d/consul.hcl
server = false
client_addr = "0.0.0.0"
bind_addr = "{{ GetInterfaceIP \"ens5\" }}"
encrypt = "h65lqS3w4x42KP+n4Hn9RtK84Rx7zP3WSahZSyD5i1o="
data_dir = "/var/lib/consul/data"
retry_join = ["${server_ip}"]
acl {
  enabled = false
}
ports {
  grpc = 8502
}
connect {
  enabled = true
}
EOCONFIG

sudo cat <<EOCONFIG > /etc/nomad.d/nomad.hcl
data_dir = "/var/lib/nomad/data"
bind_addr = "{{ GetInterfaceIP \"ens5\" }}"
advertise {
//  http = "{{ GetInterfaceIP \"ens5\" }}"
  rpc  = "{{ GetInterfaceIP \"ens5\" }}"
  serf = "{{ GetInterfaceIP \"ens5\" }}"
}

client {
  enabled = true
  network_interface = "ens5"
  options = {
   "driver.raw_exec.enable" = "1"
  }
}

EOCONFIG

sudo systemctl enable consul
sudo systemctl enable nomad
sudo systemctl start consul
sleep 1
sudo systemctl start nomad
