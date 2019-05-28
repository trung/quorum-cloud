variable "number_of_nodes" {
  default = 3
}

variable "vpc_id" {}

variable "output_dir" {}

variable "ssh_public_key" {}

variable "network_name" {}

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

resource "aws_key_pair" "ssh" {
  public_key      = "${var.ssh_public_key}"
  key_name_prefix = "${var.network_name}"
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
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "10.0.0.0/8",
    ]

    description = "From other VPC peering CIDR"
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

  ingress {
    from_port = 8
    to_port   = 0
    protocol  = "icmp"

    cidr_blocks = [
      "10.0.0.0/8",
    ]

    description = "Ping"
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
  instance_type               = "t2.medium"
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

mkdir -p /quorum/tm
mkdir -p /quorum/qdata
mkdir -p /quorum/bin

cd /quorum/bin
wget "https://bintray.com/quorumengineering/quorum/download_file?file_path=v2.2.3%2Fgeth_v2.2.3_linux_amd64.tar.gz" -O geth.tar.gz
tar xfvz geth.tar.gz
rm geth.tar.gz
wget "https://oss.sonatype.org/content/groups/public/com/jpmorgan/quorum/tessera-app/0.9/tessera-app-0.9-app.jar" -O tessera.jar
java -jar tessera.jar -keygen -filename /quorum/tm/tm < /dev/null
cat <<F > .profile
export PATH=$${PATH}:/quorum/bin
export TESSERA_JAR=/quorum/bin/tessera.jar
F

chown -R ubuntu:ubuntu /quorum
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
