variable "network_name" {}

variable "access_cidr_blocks" {
  type    = "list"
  default = []
}

variable "ingress_security_group_id" {}

variable "subnet_id" {}

variable "vpc_id" {}

locals {
  ethstats_docker_image  = "puppeth/ethstats:latest"
  ethstats_port          = 3000
  ethstats_external_port = 3000
}

data "aws_ami" "this" {
  most_recent = true

  filter {
    name = "name"

    values = [
      "amzn2-ami-hvm-*",
    ]
  }

  filter {
    name = "virtualization-type"

    values = [
      "hvm",
    ]
  }

  filter {
    name = "architecture"

    values = [
      "x86_64",
    ]
  }

  owners = [
    "137112412989",
  ]

  # amazon
}

resource "random_id" "ethstats_secret" {
  byte_length = 16
}

resource "aws_instance" "ethstats" {
  ami           = "${data.aws_ami.this.id}"
  instance_type = "t2.large"

  vpc_security_group_ids = [
    "${aws_security_group.bastion-ethstats.id}",
  ]

  subnet_id                   = "${var.subnet_id}"
  associate_public_ip_address = "true"

  user_data = <<EOF
#!/bin/bash

set -e

# START: added per suggestion from AWS support to mitigate an intermittent failures from yum update
sleep 20
yum clean all
yum repolist
# END

yum -y update
yum -y install jq
amazon-linux-extras install docker -y
systemctl enable docker
systemctl start docker
docker run -d -e "WS_SECRET=${random_id.ethstats_secret.hex}" -p ${local.ethstats_port}:${local.ethstats_external_port} ${local.ethstats_docker_image}

EOF

  tags {
    Name = "ethstats-${var.network_name}"
    By   = "quorum"
  }
}

resource "aws_security_group" "bastion-ethstats" {
  name        = "ethstats-${var.network_name}"
  description = "Security group used by external to access ethstats for Quorum network ${var.network_name}"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port = "${local.ethstats_external_port}"
    protocol  = "tcp"
    to_port   = "${local.ethstats_external_port}"

    cidr_blocks = [
      "73.150.1.0/24",
      "199.253.0.0/16",
      "${var.access_cidr_blocks}",
    ]

    description = "Allow accessing ethstats from external"
  }

  ingress {
    from_port       = "${local.ethstats_external_port}"
    protocol        = "tcp"
    to_port         = "${local.ethstats_external_port}"
    security_groups = ["${var.ingress_security_group_id}"]
    description     = "Allow pushing data to ethstats"
  }

  egress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0

    cidr_blocks = [
      "0.0.0.0/0",
    ]

    description = "Allow all"
  }

  tags {
    Name    = "ethstats-${var.network_name}"
    Network = "${var.network_name}"
    By      = "quorum"
  }
}

output "ethstats_uri" {
  value = "${random_id.ethstats_secret.hex}@${aws_instance.ethstats.private_ip}:${local.ethstats_external_port}"
}

output "ethstats_ui" {
  value = "http://${aws_instance.ethstats.public_dns}:${local.ethstats_external_port}"
}
