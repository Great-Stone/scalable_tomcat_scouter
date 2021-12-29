variable "region" {
  default = "ap-northeast-2"
}

variable "cni-version" {
  default = "1.0.1"
}

locals {
  nomad_url  = "https://releases.hashicorp.com/nomad/1.2.3/nomad_1.2.3_windows_amd64.zip"
  consul_url = "https://releases.hashicorp.com/consul/1.11.1/consul_1.11.1_windows_amd64.zip"
  jre_url    = "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.13%2B8/OpenJDK11U-jre_x64_windows_hotspot_11.0.13_8.zip"
}

packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "example" {
  ami_name      = "gs_demo_windows_{{timestamp}}"
  communicator  = "winrm"
  instance_type = "t2.micro"
  region        = var.region
  source_ami_filter {
    filters = {
      name                = "*Windows_Server-2019-English-Full-Base*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  user_data_file = "./bootstrap_win.txt"
  winrm_password = "SuperS3cr3t!!!!"
  winrm_username = "Administrator"
}

build {
  sources = ["source.amazon-ebs.example"]

  provisioner "powershell" {
    inline = [
      "New-Item \"C:\\temp\" -ItemType Directory",
    ]
  }

  // provisioner "file" {
  //   source = "./file/"
  //   destination = "/tmp"
  // }

  provisioner "powershell" {
    inline = [
      "New-Item \"C:\\hashicorp\\jre\\\" -ItemType Directory",
      "New-Item \"C:\\hashicorp\\consul\\bin\\\" -ItemType Directory",
      "New-Item \"C:\\hashicorp\\consul\\data\\\" -ItemType Directory",
      "New-Item \"C:\\hashicorp\\consul\\conf\\\" -ItemType Directory",
      "New-Item \"C:\\hashicorp\\nomad\\bin\\\" -ItemType Directory",
      "New-Item \"C:\\hashicorp\\nomad\\data\\\" -ItemType Directory",
      "New-Item \"C:\\hashicorp\\nomad\\conf\\\" -ItemType Directory",
      "Invoke-WebRequest -Uri ${local.jre_url} -OutFile $env:TEMP\\jre.zip",
      "Invoke-WebRequest -Uri ${local.consul_url} -OutFile $env:TEMP\\consul.zip",
      "Invoke-WebRequest -Uri ${local.nomad_url} -OutFile $env:TEMP\\nomad.zip",
      "Expand-Archive $env:TEMP\\jre.zip -DestinationPath C:\\hashicorp\\jre\\",
      "Expand-Archive $env:TEMP\\consul.zip -DestinationPath C:\\hashicorp\\consul\\bin\\",
      "Expand-Archive $env:TEMP\\nomad.zip -DestinationPath C:\\hashicorp\\nomad\\bin\\",
      "[Environment]::SetEnvironmentVariable(\"Path\", $env:Path + \";C:\\hashicorp\\jre\\jdk-11.0.13+8-jre\\bin;C:\\hashicorp\\nomad\\bin;C:\\hashicorp\\consul\\bin\", \"Machine\")",
      // "$old = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Session Manager\\Environment' -Name path).path",
      // "$new = \"$old;C:\\hashicorp\\jre\\jdk-11.0.13+8-jre\\bin;C:\\hashicorp\\nomad\\bin;C:\\hashicorp\\consul\\bin\"",
      // "Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Session Manager\\Environment' -Name path -Value $new",
    ]
  }
}