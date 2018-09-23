output "aws-ecr-repository" {
  value = "${aws_ecr_repository.this.repository_url}"
}

output "green-alb-dns-name" {
  value = "${module.alb-feweb-bg.dns_name}"
}

output "blue-alb-dns-name" {
  value = "${module.alb-feweb-blue-bg.dns_name}"
}
