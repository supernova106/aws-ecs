# ALB
module "alb-security-group" {
  source = "terraform-aws-modules/security-group/aws"

  version     = "2.5.0"
  name        = "${var.environment_prefix}-${var.cluster_name}-feweb-alb"
  description = "Allow inbound traffic for alb"
  vpc_id      = "${var.vpc_id}"

  ingress_with_cidr_blocks = [
    {
      rule        = "https-443-tcp"
      description = "Allow HTTPS"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      rule        = "http-80-tcp"
      description = "Allow HTTP"
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  egress_with_cidr_blocks = [
    {
      rule        = "all-all"
      description = "Allow all outbound"
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  tags {
    Environment = "${var.environment_prefix}"
  }
}

module "alb-feweb-bg" {
  source                    = "terraform-aws-modules/alb/aws"
  version                   = "3.4.0"
  load_balancer_name        = "${var.environment_prefix}-${var.cluster_name}-feweb-green"
  security_groups           = ["${module.alb-security-group.this_security_group_id}"]
  logging_enabled           = false
  load_balancer_is_internal = true
  subnets                   = ["${data.aws_subnet_ids.private.ids}"]
  vpc_id                    = "${var.vpc_id}"
  https_listeners_count     = "0"
  http_tcp_listeners        = "${list(map("port", "80", "protocol", "HTTP"))}"
  http_tcp_listeners_count  = "1"
  target_groups             = "${list(map("name", "${var.environment_prefix}-${var.cluster_name}-feweb-green-tg", "backend_protocol", "HTTP", "backend_port", "80", "target_type", "ip"))}"
  target_groups_count       = "1"

  tags = {
    Environment = "${var.environment}"
    Terraform   = "true"
  }
}

module "alb-feweb-blue-bg" {
  source                    = "terraform-aws-modules/alb/aws"
  version                   = "3.4.0"
  load_balancer_name        = "${var.environment_prefix}-${var.cluster_name}-feweb-blue"
  security_groups           = ["${module.alb-security-group.this_security_group_id}"]
  logging_enabled           = false
  load_balancer_is_internal = true
  subnets                   = ["${data.aws_subnet_ids.private.ids}"]
  vpc_id                    = "${var.vpc_id}"
  https_listeners_count     = "0"
  http_tcp_listeners        = "${list(map("port", "80", "protocol", "HTTP"))}"
  http_tcp_listeners_count  = "1"
  target_groups             = "${list(map("name", "${var.environment_prefix}-${var.cluster_name}-feweb-blue-tg", "backend_protocol", "HTTP", "backend_port", "80", "target_type", "ip"))}"
  target_groups_count       = "1"

  tags = {
    Environment = "${var.environment}"
    Terraform   = "true"
  }
}

# ECR
resource "aws_ecr_repository" "this" {
  name = "${var.environment_prefix}-${var.cluster_name}-ecr"
}

# ECS

resource "aws_ecs_cluster" "this" {
  name = "${var.environment_prefix}-${var.cluster_name}"
}

resource "aws_ecs_service" "green-feweb" {
  name            = "${var.environment_prefix}-${var.cluster_name}-green-feweb"
  cluster         = "${aws_ecs_cluster.this.id}"
  task_definition = "${aws_ecs_task_definition.feweb-green.arn}"
  desired_count   = 2
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = "${module.alb-feweb-bg.target_group_arns[0]}"
    container_name   = "feweb"
    container_port   = 80
  }

  network_configuration {
    subnets         = ["${data.aws_subnet_ids.private.ids}"]
    security_groups = ["${module.app-security-group.this_security_group_id}"]
  }

  lifecycle {
    ignore_changes = ["desired_count"]
  }
}

resource "aws_ecs_service" "blue-feweb" {
  name            = "${var.environment_prefix}-${var.cluster_name}-blue-feweb"
  cluster         = "${aws_ecs_cluster.this.id}"
  task_definition = "${aws_ecs_task_definition.feweb-blue.arn}"
  desired_count   = 2
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = "${module.alb-feweb-blue-bg.target_group_arns[0]}"
    container_name   = "feweb"
    container_port   = 80
  }

  network_configuration {
    subnets         = ["${data.aws_subnet_ids.private.ids}"]
    security_groups = ["${module.app-security-group.this_security_group_id}"]
  }

  lifecycle {
    ignore_changes = ["desired_count"]
  }
}

# Task definition
module "app-security-group" {
  source = "terraform-aws-modules/security-group/aws"

  version     = "2.5.0"
  name        = "${var.environment_prefix}-${var.cluster_name}-feweb-app"
  description = "Allow inbound traffic for app"
  vpc_id      = "${var.vpc_id}"

  ingress_with_cidr_blocks = [
    {
      rule        = "https-443-tcp"
      description = "Allow HTTPS"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      rule        = "http-80-tcp"
      description = "Allow HTTP"
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  egress_with_cidr_blocks = [
    {
      rule        = "all-all"
      description = "Allow all outbound"
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  tags {
    Environment = "${var.environment_prefix}"
  }
}

data "template_file" "task-definition-green-feweb" {
  template = "${file("task-definitions/green-feweb.json")}"
}

resource "aws_ecs_task_definition" "feweb-green" {
  family                = "${var.environment_prefix}-${var.cluster_name}-green-feweb"
  container_definitions = "${data.template_file.task-definition-green-feweb.rendered}"

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = 256
  memory = 512

  volume {
    name = "feweb-storage"
  }
}

data "template_file" "task-definition-blue-feweb" {
  template = "${file("task-definitions/blue-feweb.json")}"
}

resource "aws_ecs_task_definition" "feweb-blue" {
  family                = "${var.environment_prefix}-${var.cluster_name}-blue-feweb"
  container_definitions = "${data.template_file.task-definition-blue-feweb.rendered}"

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = 256
  memory = 512

  volume {
    name = "feweb-storage"
  }
}
