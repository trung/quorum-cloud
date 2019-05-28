resource "aws_vpc_peering_connection" "us-east-1-to-eu-west-1" {
  provider    = "aws.us-east-1"
  peer_vpc_id = "${lookup(var.regionVPCs, "eu-west-1")}"
  vpc_id      = "${lookup(var.regionVPCs, "us-east-1")}"

  peer_region = "eu-west-1"

  tags {
    Name = "us-east-1-to-eu-west-1"
    By   = "quorum"
  }
}

resource "aws_vpc_peering_connection_accepter" "us-east-1-to-eu-west-1" {
  provider                  = "aws.eu-west-1"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.us-east-1-to-eu-west-1.id}"
  auto_accept               = true

  tags {
    Name = "us-east-1-to-eu-west-1"
    By   = "quorum"
  }
}

resource "aws_vpc_peering_connection" "us-east-1-to-ap-southeast-1" {
  provider    = "aws.us-east-1"
  peer_vpc_id = "${lookup(var.regionVPCs, "ap-southeast-1")}"
  vpc_id      = "${lookup(var.regionVPCs, "us-east-1")}"

  peer_region = "ap-southeast-1"

  tags {
    Name = "us-east-1-to-ap-southeast-1"
    By   = "quorum"
  }
}

resource "aws_vpc_peering_connection_accepter" "us-east-1-to-ap-southeast-1" {
  provider                  = "aws.ap-southeast-1"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.us-east-1-to-ap-southeast-1.id}"
  auto_accept               = true

  tags {
    Name = "us-east-1-to-ap-southeast-1"
    By   = "quorum"
  }
}

resource "aws_vpc_peering_connection" "eu-west-1-to-ap-southeast-1" {
  provider    = "aws.eu-west-1"
  peer_vpc_id = "${lookup(var.regionVPCs, "ap-southeast-1")}"
  vpc_id      = "${lookup(var.regionVPCs, "eu-west-1")}"

  peer_region = "ap-southeast-1"

  tags {
    Name = "eu-west-1-to-ap-southeast-1"
    By   = "quorum"
  }
}

resource "aws_vpc_peering_connection_accepter" "eu-west-1-to-ap-southeast-1" {
  provider                  = "aws.ap-southeast-1"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.eu-west-1-to-ap-southeast-1.id}"
  auto_accept               = true

  tags {
    Name = "eu-west-1-to-ap-southeast-1"
    By   = "quorum"
  }
}
