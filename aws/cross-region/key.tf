resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "local_file" "private_key" {
  filename = "${path.module}/target/${var.network_name}.pem"
  content  = "${tls_private_key.ssh.private_key_pem}"
}
