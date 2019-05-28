variable "name" {
  description = "Name of the Quorum Cluster. Used to tag all resources being created"
}

variable "region" {
  default = "us-east-1"
}

variable "number_of_nodes" {
  default = 3
}

variable "vpc_id" {}

variable "consensus" {
  default = "istanbul"
}

provider "aws" {
  region = "${var.region}"
}

module "bootstrap" {
  source          = "../../bootstrap"
  consensus       = "${var.consensus}"
  number_of_nodes = "${var.number_of_nodes}"
  node_ips        = ["${module.cluster.private_ips}"]
  output_dir      = "${path.module}/target"
}

module "cluster" {
  source          = "./node"
  network_name    = "${var.name}"
  number_of_nodes = "${var.number_of_nodes}"
  vpc_id          = "${var.vpc_id}"
  output_dir      = "${path.module}/target"
}

resource "null_resource" "publish" {
  count = "${var.number_of_nodes}"

  triggers {
    bootstrap = "${module.bootstrap.hash}"
  }

  connection {
    type        = "ssh"
    agent       = false
    timeout     = "60s"
    host        = "${element(module.cluster.ips, count.index)}"
    user        = "ubuntu"
    private_key = "${module.cluster.private_key}"
  }

  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /tmp/signal ]; do echo 'Wait for ${element(module.cluster.dns, count.index)} being fully ready'; sleep 3; done",
      "${module.bootstrap.prepare_network}"
    ]
  }

  provisioner "file" {
    source      = "${element(module.bootstrap.data_dirs, count.index)}/"
    destination = "${module.cluster.quorum_dir}"
  }

  provisioner "remote-exec" {
    inline = [
      "${module.bootstrap.start_network}",
      "sleep 3",                           // avoid connection shutting down before processes start up
    ]
  }
}

output "nodes" {
  value = "${module.cluster.dns}"
}
