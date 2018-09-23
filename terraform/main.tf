## Terraform to demonstrate deployment app behind a LB 
## Author: Binh Nguyen

provider "aws" {
  region = "${var.region}"
}

terraform {
  required_version = ">= 0.10.3" # introduction of Local Values configuration language feature

  # demo purpose so there is no S3 bucket
  # backend "s3" {
  #   bucket = ""
  #   key    = ""
  #   region = "us-west-2"
  # }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_vpc" "this" {
  id = "${var.vpc_id}"
}

data "aws_route53_zone" "this" {
  name         = "${var.route53_domain}"
  private_zone = true
}

data "aws_subnet_ids" "private" {
  vpc_id = "${var.vpc_id}"

  tags {
    Tier  = "Private"
    Group = "Generic"
  }
}

data "aws_subnet_ids" "public" {
  vpc_id = "${var.vpc_id}"

  tags {
    Tier  = "Public"
    Group = "Generic"
  }
}
