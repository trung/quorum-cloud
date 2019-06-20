variable "number_of_nodes" {
  default = 3
}

variable "vpc_id" {}

variable "output_dir" {}

variable "ssh_public_key" {
  default = ""
}

variable "network_name" {}

variable "instance_type" {
  default = "t2.medium"
}

locals {
  ssh_public_key = "${coalesce(var.ssh_public_key, join("", tls_private_key.ssh.*.public_key_openssh))}"
  quorum_dir     = "/quorum"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name = "name"

    values = [
      "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*",
    ]
  }

  filter {
    name = "virtualization-type"

    values = [
      "hvm",
    ]
  }

  owners = [
    "099720109477",
  ]

  # Canonical
}

resource "tls_private_key" "ssh" {
  count     = "${var.ssh_public_key == "" ? 1 : 0}"
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "local_file" "private_key" {
  count    = "${var.ssh_public_key == "" ? 1 : 0}"
  filename = "${var.output_dir}/${var.network_name}.pem"
  content  = "${tls_private_key.ssh.private_key_pem}"
}

resource "aws_key_pair" "ssh" {
  public_key      = "${local.ssh_public_key}"
  key_name_prefix = "${var.network_name}-"
}

resource "aws_security_group" "quorum" {
  name        = "${var.network_name}"
  description = "Allow Quorum Network traffic"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0",
    ]

    description = "SSH"
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  tags {
    Name = "${var.network_name}"
    By   = "quorum"
  }
}

data "aws_subnet_ids" "node" {
  vpc_id = "${var.vpc_id}"
}

resource "aws_instance" "node" {
  count = "${var.number_of_nodes}"

  ami                         = "${data.aws_ami.ubuntu.id}"
  instance_type               = "${var.instance_type}"
  associate_public_ip_address = true
  key_name                    = "${aws_key_pair.ssh.key_name}"
  subnet_id                   = "${element(data.aws_subnet_ids.node.ids, 0)}"

  vpc_security_group_ids = [
    "${aws_security_group.quorum.id}",
  ]

  user_data = <<EOF
#!/bin/bash

apt-get update
apt-get -y install openjdk-8-jdk unzip

mkdir -p ${local.quorum_dir}/tm
mkdir -p ${local.quorum_dir}/qdata
mkdir -p ${local.quorum_dir}/bin

cd ${local.quorum_dir}/bin
wget "https://bintray.com/quorumengineering/quorum/download_file?file_path=v2.2.4%2Fgeth_v2.2.4_linux_amd64.tar.gz" -O geth.tar.gz
tar xfvz geth.tar.gz
rm geth.tar.gz
wget "https://oss.sonatype.org/content/groups/public/com/jpmorgan/quorum/tessera-app/0.9.2/tessera-app-0.9.2-app.jar" -O tessera.jar
java -jar tessera.jar -keygen -filename ${local.quorum_dir}/tm/tm < /dev/null
cat <<F > .profile
export PATH=$${PATH}:${local.quorum_dir}/bin
export TESSERA_JAR=${local.quorum_dir}/bin/tessera.jar
F

chown -R ubuntu:ubuntu ${local.quorum_dir}

touch /tmp/signal
EOF

  tags = {
    By   = "quorum"
    Name = "${var.network_name}-node-${count.index}"
  }
}

output "private_ips" {
  value = "${aws_instance.node.*.private_ip}"
}

output "ips" {
  value = "${aws_instance.node.*.public_ip}"
}

output "dns" {
  value = "${aws_instance.node.*.public_dns}"
}

output "names" {
  value = "${aws_instance.node.*.tags.Name}"
}

output "private_key" {
  value = "${join("", tls_private_key.ssh.*.private_key_pem)}"
}

output "quorum_dir" {
  value = "${local.quorum_dir}"
}

output "security_group_id" {
  value = "${aws_security_group.quorum.id}"
}
