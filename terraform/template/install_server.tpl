#!/bin/bash
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository 'deb [arch=amd64] https://apt.releases.hashicorp.com bionic main'
sudo apt-get update && sudo apt-get -y install consul nomad netcat

for SOLUTION in "consul" "nomad";
do
    sudo mkdir -p /var/lib/$SOLUTION/{data,plugins}
    sudo chown -R $SOLUTION:$SOLUTION /var/lib/$SOLUTION
done

sudo cat <<EOCONFIG > /etc/consul.d/consul.hcl
server = true
ui_config {
  enabled = true
}
bootstrap_expect = 1
client_addr = "0.0.0.0"
bind_addr = "{{ GetInterfaceIP \"ens5\" }}"
encrypt = "h65lqS3w4x42KP+n4Hn9RtK84Rx7zP3WSahZSyD5i1o="
data_dir = "/var/lib/consul/data"
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
server {
  enabled          = true
  bootstrap_expect = 1
  encrypt = "H6NAbsGpPXKJIww9ak32DAV/kKAm7vh9awq0fTtUou8="
}
EOCONFIG

sudo systemctl enable consul
sudo systemctl enable nomad
sudo systemctl start consul
sleep 1
sudo systemctl start nomad
