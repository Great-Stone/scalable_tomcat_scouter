resource "aws_vpc" "example" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    "kubernetes.io/cluster/example" = "shared"
  }
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.10.0/24"
  availability_zone       = data.aws_availability_zones.available.names.0
  map_public_ip_on_launch = true
  tags = {
    "kubernetes.io/cluster/example" = "shared"
  }
}

resource "aws_subnet" "sub" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.20.0/24"
  availability_zone       = data.aws_availability_zones.available.names.1
  map_public_ip_on_launch = true
  tags = {
    "kubernetes.io/cluster/example" = "shared"
  }
}

resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id
}

resource "aws_eip" "example" {
  vpc = true
}

resource "aws_nat_gateway" "example" {
  allocation_id = aws_eip.example.id
  subnet_id     = aws_subnet.main.id
}

resource "aws_default_route_table" "example" {
  default_route_table_id = aws_vpc.example.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.example.id
  }
}

resource "aws_route_table_association" "example" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_default_route_table.example.id
}

resource "aws_default_network_acl" "example" {
  default_network_acl_id = aws_vpc.example.default_network_acl_id

  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 65535
  }

  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
}

resource "aws_default_security_group" "example" {
  vpc_id = aws_vpc.example.id

  ingress {
    protocol    = "tcp"
    from_port   = 0
    to_port     = 65535
    cidr_blocks = [aws_vpc.example.cidr_block]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
  sg_tcp_ports = [22, 3389, 8200, 8500, 8502, 8300, 8301, 8302, 8600, 4646, 4647, 5432, 8080, 6100]
  sg_udp_ports = [8301, 8302, 8600, 6100]
}

resource "aws_security_group" "example" {
  vpc_id = aws_vpc.example.id
  name   = "${var.prefix}-sg"

  dynamic "ingress" {
    for_each = local.sg_tcp_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  dynamic "ingress" {
    for_each = local.sg_udp_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "udp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## RDS 구성
resource "aws_security_group" "rds" {
  name   = "postgresql_rds"
  vpc_id = aws_vpc.example.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "education_rds"
  }
}

## EC2 구성
data "template_file" "server" {
  template = file("./template/install_server.tpl")
}


data "template_file" "client" {
  template = file("./template/install_client.tpl")

  vars = {
    server_ip = aws_instance.server.private_ip
  }
}

resource "aws_key_pair" "example" {
  key_name   = "${var.prefix}-key-pair"
  public_key = file(".ssh/id_rsa.pub")
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["711129375688"]
  filter {
    name   = "name"
    values = ["gs_demo_ubuntu_*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "windows" {
  most_recent = true
  owners      = ["711129375688"]
  filter {
    name   = "name"
    values = ["gs_demo_windows_*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_eip" "server" {
  vpc      = true
  instance = aws_instance.server.id
}

resource "aws_instance" "server" {
  // ami           = "ami-0ba5cd124d7a79612" // ubuntu 18.04 LTS
  subnet_id     = aws_subnet.main.id
  ami           = data.aws_ami.ubuntu.image_id
  instance_type = "m5.large"
  key_name      = aws_key_pair.example.key_name
  vpc_security_group_ids = [
    aws_security_group.example.id
  ]
  user_data = data.template_file.server.rendered

  tags = {
    type = "server"
  }

  lifecycle {
    ignore_changes = [
      user_data,
    ]
  }
}

resource "aws_instance" "ubuntu" {
  count         = var.client_ubuntu_count
  subnet_id     = aws_subnet.main.id
  ami           = data.aws_ami.ubuntu.image_id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.example.key_name
  vpc_security_group_ids = [
    aws_security_group.example.id
  ]
  user_data = data.template_file.client.rendered

  lifecycle {
    ignore_changes = [
      user_data,
    ]
  }
}

resource "aws_instance" "windows" {
  count         = var.client_windows_count
  subnet_id     = aws_subnet.main.id
  ami           = data.aws_ami.windows.image_id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.example.key_name
  vpc_security_group_ids = [
    aws_security_group.example.id
  ]
  // user_data = data.template_file.client.rendered
}

#### 환경변수
resource "local_file" "env_sh" {
  content  = <<-EOT
      export VAULT_ADDR=http://${aws_eip.server.public_ip}:8200
      export CONSUL_HTTP_ADDR=http://${aws_eip.server.public_ip}:8500
      export NOMAD_ADDR=http://${aws_eip.server.public_ip}:4646
    EOT
  filename = "env.sh"
}
