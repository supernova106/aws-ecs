variable "region" {
  type    = "string"
  default = "us-west-2"
}

variable "availability_zones" {
  type    = "list"
  default = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "environment" {
  type    = "string"
  default = "dev"
}

variable "environment_prefix" {
  type    = "string"
  default = "test"
}

variable "cluster_name" {
  type    = "string"
  default = "bg1"
}

variable "vpc_id" {}

variable "route53_domain" {}

variable "github_oauth" {}
