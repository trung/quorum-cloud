variable "consensus" {
  default = "istanbul"
}

variable "output_dir" {
  default = "target"
}

variable "node_ips" {
  type = "list"
}

variable "number_of_nodes" {
  description = "must be equal to length(node_ips)"
}
