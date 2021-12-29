// nomad namespace apply -description "scouter" scouter

variable "version" {
  default = "2.15.0"
}

locals {
  souter_release_url = "https://github.com/scouter-project/scouter/releases/download/v${var.version}/scouter-min-${var.version}.tar.gz"
}

job "scouter-collector" {
  datacenters = ["dc1"]
  // namespace = "scouter"

  type = "service"

  constraint {
    attribute = "${attr.kernel.name}"
    value     = "linux"
  }
  constraint {
    attribute = "${attr.unique.hostname}"
    value     = "ip-10-0-10-119"
  }

  group "collector" {
    count = 1

    scaling {
      enabled = false
      min = 1
      max = 1
    }

    ephemeral_disk {
      migrate = true
      size    = 500
      sticky  = true
    }

    task "collector" {
      driver = "java"
      resources {
        network {
          port "collector" {
            to = 6100
            static = 6100
          }
        }
        cpu = 100
        memory = 256
      }
      artifact {
        source = local.souter_release_url
        destination = "/local"
      }
      template {
data = <<EOF
# Agent Control and Service Port(Default : TCP 6100)
net_tcp_listen_port={{ env "NOMAD_PORT_collector" }}

# UDP Receive Port(Default : 6100)
net_udp_listen_port={{ env "NOMAD_PORT_collector" }}

# DB directory(Default : ./database)
db_dir=./database

# Log directory(Default : ./logs)
log_dir=./logs
EOF
        destination = "local/scouter/server/conf/scouter.conf"
      }
      config {
        class_path = "local/scouter/server/scouter-server-boot.jar"
        class = "scouter.boot.Boot"
        args = ["local/scouter/server/lib"]
      }
      service {
        name = "scouter-collector"
        tags = ["scouter"]

        port = "collector"

        check {
          type  = "tcp"
          interval = "10s"
          timeout  = "2s"
          port  = "collector"
        }
      }
    }
  }
}
