# Scalable Java - Windows Setup

## Packer

> on AWS env
> download : https://releases.hashicorp.com/packer/

### ubuntu build
```bash
cd ./packer
packer build ./ubuntu.pkr.hcl
```

### windows build
```bash
cd ./packer
packer build ./windows.pkr.hcl
```

## Terraform

> download : https://releases.hashicorp.com/terraform/

### tfvars example
```hcl
default_tags = {
  Name        = "gs"
  environment = "Demo"
  owner       = "demo@demo.com"
  project     = "Scalable Java Demo"
  ttl         = 3
}

prefix = "gs"

client_ubuntu_count = 2
client_windows_count = 1
```

## Windows Setup

### Consul Conf file
```hcl
# C:\hashicorp\consul\conf\consul.hcl
server = false
client_addr = "0.0.0.0"
bind_addr = "10.0.10.212"
encrypt = "h65lqS3w4x42KP+n4Hn9RtK84Rx7zP3WSahZSyD5i1o="
data_dir = "C:\\hashicorp\\consul\\data"
retry_join = ["10.0.10.246"]
acl {
  enabled = false
}
ports {
  grpc = 8502
}
connect {
  enabled = true
}
```

### add sc Consul
```bash
sc.exe create Consul binPath= "C:\hashicorp\consul\bin\consul.exe agent -config-dir=C:\hashicorp\consul\conf" start= auto

net start Consul

sc.exe delete Consul
```

### Nomad Conf file
```hcl
# C:\hashicorp\nomad\conf\nomad.hcl
data_dir = "C:\\hashicorp\\nomad\\data"

bind_addr = "0.0.0.0"

consul {
  address = "127.0.0.1:8500"
}

server {
  enabled = false
}

server_join {
  retry_join = ["10.0.10.246:4647"]
}

client {
  enabled = true
  meta {
    "subject" = "client"
    "target" = "win"
  }
  options = {
    "driver.raw_exec.enable" = "1"
  }
}
```

### add sc Nomad
```bash
sc.exe create Nomad binPath= "C:\hashicorp\nomad\bin\nomad.exe agent -config=C:\hashicorp\nomad\conf" start= auto

net start Nomad

sc.exe delete Nomad
```