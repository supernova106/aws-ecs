resource "aws_route53_record" "feweb-blue" {
  zone_id = "${data.aws_route53_zone.this.zone_id}"
  name    = "${var.environment_prefix}-${var.cluster_name}.${var.route53_domain}"
  type    = "CNAME"
  ttl     = "5"

  weighted_routing_policy {
    weight = 10
  }

  set_identifier = "dev"
  records        = ["${module.alb-feweb-blue-bg.dns_name}"]
}

resource "aws_route53_record" "feweb-green" {
  zone_id = "${data.aws_route53_zone.this.zone_id}"
  name    = "${var.environment_prefix}-${var.cluster_name}.${var.route53_domain}"
  type    = "CNAME"
  ttl     = "5"

  weighted_routing_policy {
    weight = 90
  }

  set_identifier = "live"
  records        = ["${module.alb-feweb-bg.dns_name}"]
}
