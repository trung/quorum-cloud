provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "eu-west-1"
  region = "eu-west-1"
}

provider "aws" {
  alias  = "ap-southeast-1"
  region = "ap-southeast-1"
}

locals {
  peers = [
    "us-east-1,eu-west-1",
    "us-east-1,ap-southeast-1",
    "eu-west-1,ap-southeast-1",
  ]

  number_of_nodes = "${var.regionNodeCount["us-east-1"] + var.regionNodeCount["eu-west-1"] + var.regionNodeCount["ap-southeast-1"]}"
  node_ips        = "${concat(module.us-east-1-nodes.private_ips, module.eu-west-1-nodes.private_ips, module.ap-southeast-1-nodes.private_ips)}"
  node_public_ips = "${concat(module.us-east-1-nodes.ips, module.eu-west-1-nodes.ips, module.ap-southeast-1-nodes.ips)}"
}

module "bootstrap" {
  source          = "../bootstrap"
  consensus       = "istanbul"
  output_dir      = "${path.module}/target"
  node_ips        = "${local.node_ips}"
  number_of_nodes = "${local.number_of_nodes}"
}

module "us-east-1-nodes" {
  source     = "../ec2/node"
  output_dir = "${path.module}/target"

  providers = {
    aws = "aws.us-east-1"
  }

  vpc_id          = "${lookup(var.regionVPCs, "us-east-1")}"
  number_of_nodes = "${var.regionNodeCount["us-east-1"]}"
  ssh_public_key  = "${tls_private_key.ssh.public_key_openssh}"
  network_name    = "${var.network_name}"
}

module "eu-west-1-nodes" {
  source     = "../ec2/node"
  output_dir = "${path.module}/target"

  providers = {
    aws = "aws.eu-west-1"
  }

  vpc_id          = "${lookup(var.regionVPCs, "eu-west-1")}"
  number_of_nodes = "${var.regionNodeCount["eu-west-1"]}"
  ssh_public_key  = "${tls_private_key.ssh.public_key_openssh}"
  network_name    = "${var.network_name}"
}

module "ap-southeast-1-nodes" {
  source     = "../ec2/node"
  output_dir = "${path.module}/target"

  providers = {
    aws = "aws.ap-southeast-1"
  }

  vpc_id          = "${lookup(var.regionVPCs, "ap-southeast-1")}"
  number_of_nodes = "${var.regionNodeCount["ap-southeast-1"]}"
  ssh_public_key  = "${tls_private_key.ssh.public_key_openssh}"
  network_name    = "${var.network_name}"
}

resource "null_resource" "publish" {
  count = "${local.number_of_nodes}"

  triggers {
    ips       = "${join("|", local.node_ips)}"
    bootstrap = "${module.bootstrap.hash}"
  }

  connection {
    type        = "ssh"
    agent       = false
    timeout     = "60s"
    host        = "${element(local.node_public_ips, count.index)}"
    user        = "ubuntu"
    private_key = "${tls_private_key.ssh.private_key_pem}"
  }

  provisioner "remote-exec" {
    inline = ["${module.bootstrap.prepare_network}"]
  }

  provisioner "file" {
    source      = "${element(module.bootstrap.data_dirs, count.index)}/"
    destination = "/quorum"
  }

  provisioner "remote-exec" {
    inline = [
      "${module.bootstrap.start_network}",
      "sleep 3",                           // avoid connection shutting down before processes start up
    ]
  }
}

output "nodes" {
  value = {
    "us-east-1" = {
      ips = "${module.us-east-1-nodes.ips}"
      dns = "${module.us-east-1-nodes.dns}"
    }

    "eu-west-1" = {
      ips = "${module.eu-west-1-nodes.ips}"
      dns = "${module.eu-west-1-nodes.dns}"
    }

    "ap-southeast-1" = {
      ips = "${module.ap-southeast-1-nodes.ips}"
      dns = "${module.ap-southeast-1-nodes.dns}"
    }
  }
}

output "data_dirs" {
  value = [
    "${module.bootstrap.data_dirs}",
  ]
}
