variable "regionVPCs" {
  type = "map"

  default = {
    "us-east-1"      = ""
    "eu-west-1"      = ""
    "ap-southeast-1" = ""
  }
}

variable "regionNodeCount" {
  type = "map"

  default = {
    "us-east-1"      = 1
    "eu-west-1"      = 1
    "ap-southeast-1" = 1
  }
}

variable "network_name" {}
