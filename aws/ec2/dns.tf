data "aws_route53_zone" "private" {
  name         = "goquorum.com."
  private_zone = true
}

resource "aws_route53_record" "nodes" {
  count   = "${var.number_of_nodes}"
  name    = "node${count.index + 1}.${var.name}.${data.aws_route53_zone.private.name}"
  type    = "A"
  ttl     = 300
  zone_id = "${data.aws_route53_zone.private.zone_id}"
  records = ["${element(module.cluster.private_ips, count.index)}"]
}
