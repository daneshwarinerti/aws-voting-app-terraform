# AWS Voting App - Terraform

A cloud-based voting application deployed on AWS using Terraform, Docker, Amazon ECS, Amazon ECR, RDS PostgreSQL, ElastiCache Redis, and GitHub Actions.

## Architecture

GitHub
   |
   v
GitHub Actions
   |
   v
Amazon ECR
   |
   v
Amazon ECS (Fargate)
   |
   +---- Voting App
   |
   +---- Result App
   |
   +---- Worker
          |
          +---- RDS PostgreSQL
          |
          +---- ElastiCache Redis

Application traffic
        |
        v
Application Load Balancer

AWS Services Used
Amazon VPC
Amazon ECS (Fargate)
Amazon ECR
Amazon RDS PostgreSQL
Amazon ElastiCache Redis
Application Load Balancer
IAM
AWS Secrets Manager
Amazon CloudWatch Logs
NAT Gateway
GitHub Actions
Technologies
Terraform
Docker
.NET
PostgreSQL
Redis
GitHub Actions
AWS
Application Components
Voting App

Accepts votes from users through the web application.

Worker

Processes votes and communicates with:

Redis
PostgreSQL
Result App

Displays the voting results.

Infrastructure

The AWS infrastructure is created using Terraform.

Terraform manages:

VPC and subnets
Security groups
ECS cluster and services
ECR repositories
RDS PostgreSQL
ElastiCache Redis
Application Load Balancer
IAM roles and policies
CloudWatch log groups
Secrets Manager integration
CI/CD Pipeline

GitHub Actions automatically:

Checks out the source code.
Authenticates with AWS using GitHub OIDC.
Builds Docker images.
Pushes images to Amazon ECR.
Updates ECS services.
Forces a new ECS deployment.
Security

GitHub Actions uses AWS IAM OIDC authentication instead of storing long-term AWS access keys.

The PostgreSQL password is stored in AWS Secrets Manager and injected into ECS using the secrets configuration.

Deployment

Initialize Terraform:

terraform init

Check the infrastructure:

terraform plan

Deploy:

terraform apply
Project Structure
aws-voting-app-terraform/
│
├── application/
│   ├── vote/
│   ├── result/
│   └── worker/
│
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   └── github-actions-ecs.tf
│
├── .github/
│   └── workflows/
│       └── build-and-push.yml
│
├── .gitignore
└── README.md
