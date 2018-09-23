resource "aws_s3_bucket" "codepipeline" {
  bucket = "${var.environment_prefix}-${var.cluster_name}-codepipeline.${var.region}"
  acl    = "private"
}

resource "aws_iam_role" "codepipeline" {
  name = "${var.environment_prefix}-${var.cluster_name}-codepipeline-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codepipeline" {
  name = "${var.environment_prefix}-${var.cluster_name}-codepipeline-policy"
  role = "${aws_iam_role.codepipeline.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.codepipeline.arn}",
        "${aws_s3_bucket.codepipeline.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_codepipeline" "this" {
  name     = "${var.environment_prefix}-${var.cluster_name}-pipeline"
  role_arn = "${aws_iam_role.codepipeline.arn}"

  artifact_store {
    location = "${aws_s3_bucket.codepipeline.bucket}"
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["feweb"]

      configuration {
        Owner      = "supernova106"
        Repo       = "httpd"
        Branch     = "master"
        OAuthToken = "${var.github_oauth}"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["feweb"]
      version         = "1"

      configuration {
        ProjectName = "${var.environment_prefix}-${var.cluster_name}-feweb"
      }
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name = "${var.environment_prefix}-${var.cluster_name}-codebuild"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codebuild" {
  role = "${aws_iam_role.codebuild.name}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeDhcpOptions",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVpcs"
      ],
      "Resource": "*"
    },
    {
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:GetAuthorizationToken",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ],
      "Resource": "*",
      "Effect": "Allow"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.codepipeline.arn}",
        "${aws_s3_bucket.codepipeline.arn}/*"
      ]
    }
  ]
}
POLICY
}

module "codebuild-security-group" {
  source = "terraform-aws-modules/security-group/aws"

  version     = "2.5.0"
  name        = "${var.environment_prefix}-${var.cluster_name}-codebuild-app"
  description = "Allow inbound traffic for codebuild"
  vpc_id      = "${var.vpc_id}"

  ingress_with_cidr_blocks = [
    {
      rule        = "all-all"
      description = "Allow all inbound"
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

resource "aws_codebuild_project" "feweb" {
  name          = "${var.environment_prefix}-${var.cluster_name}-feweb"
  description   = "Build Apache Webserver Docker Image"
  build_timeout = "10"
  service_role  = "${aws_iam_role.codebuild.arn}"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/docker:17.09.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable = [
      {
        name  = "AWS_DEFAULT_REGION"
        value = "${var.region}"
      },
      {
        name  = "AWS_ACCOUNT_ID"
        value = "${data.aws_caller_identity.current.account_id}"
      },
      {
        name  = "IMAGE_REPO_NAME"
        value = "${aws_ecr_repository.this.name}"
      },
      {
        name  = "IMAGE_TAG"
        value = "latest"
      },
    ]
  }

  cache {
    type     = "S3"
    location = "${aws_s3_bucket.codepipeline.bucket}"
  }

  source {
    type = "CODEPIPELINE"
  }

  vpc_config {
    vpc_id = "${var.vpc_id}"

    subnets = ["${data.aws_subnet_ids.private.ids}"]

    security_group_ids = [
      "${module.codebuild-security-group.this_security_group_id}",
    ]
  }

  tags {
    "Environment" = "${var.environment}"
  }
}
