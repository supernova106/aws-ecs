# Canary Deployment with Blue-Green Approach

To deploy application behind a Load Balancer, in this case is simple Apache Webserver or Front End.

Services in use:

- AWS ECS (Fargate)
- AWS ALB
- AWS Route53 for weighted routing policy
- AWS CodePipeline
- AWS CodeBuild
- Github or CodeCommit
- AWS ECR
- AWS S3 for storing artifacts/logs
- AWS Cloudwatch
- AWS IAM

## Usage

- Configure your source code. By following [https://docs.aws.amazon.com/codepipeline/latest/userguide/GitHub-rotate-personal-token-CLI.html](https://docs.aws.amazon.com/codepipeline/latest/userguide/GitHub-rotate-personal-token-CLI.html)

- Setup 

```sh
cp env_sample .env
source .env
```

- To bootstrap the environment.

```
cd terraform
terraform init
terraform plan -out plan
terraform apply plan
```

- Test & Verify new environment with separate ALB endpoint
- flip the deployment by updating Route53 Policy 

Goals:

- To use fully automated CICD to deploy on ECS cluster.
- All operations happened with git commit
- Send alert when errors/retries

## Contact

Binh Nguyen
