# AWS Voting App with Terraform


A cloud-based voting application deployed on AWS using Infrastructure as Code and CI/CD automation.


## Overview


This project demonstrates the deployment of a containerized voting application on AWS using Terraform, Docker, Amazon ECS, and GitHub Actions.


The application consists of three services:


- **Voting App** – Allows users to cast votes.
- **Worker** – Processes votes using Redis and PostgreSQL.
- **Result App** – Displays the voting results.


## Technologies Used


- AWS
- Terraform
- Docker
- Amazon ECS (Fargate)
- Amazon ECR
- Amazon RDS PostgreSQL
- Amazon ElastiCache Redis
- Application Load Balancer
- AWS Secrets Manager
- AWS IAM
- Amazon CloudWatch
- GitHub Actions
- GitHub OIDC
- .NET


## AWS Infrastructure


Terraform is used to provision and manage:


- VPC
- Public and private subnets
- Internet Gateway
- NAT Gateway
- Security Groups
- Application Load Balancer
- ECS Cluster
- ECS Services
- ECR Repositories
- RDS PostgreSQL
- ElastiCache Redis
- IAM Roles and Policies
- CloudWatch Log Groups
- AWS Secrets Manager


## CI/CD


GitHub Actions automates the application deployment process.


The pipeline:


1. Checks out the source code.
2. Authenticates with AWS using GitHub OIDC.
3. Builds Docker images for the application services.
4. Pushes the images to Amazon ECR.
5. Updates the ECS services.
6. Starts a new ECS deployment.


## Security


- GitHub Actions uses **OIDC authentication** instead of storing long-term AWS access keys.
- PostgreSQL credentials are managed using **AWS Secrets Manager**.
- ECS retrieves the database password from Secrets Manager at runtime.
- AWS IAM policies provide the required permissions for ECS and GitHub Actions.


## Project Structure


```text
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
Deployment
Initialize Terraform
terraform init
Validate the configuration
terraform validate
Preview changes
terraform plan
Deploy the infrastructure
terraform apply
CI/CD Workflow

After the infrastructure is deployed, pushing changes to the main branch triggers the GitHub Actions workflow.

Code Push
   ↓
GitHub Actions
   ↓
Docker Build
   ↓
Amazon ECR
   ↓
Amazon ECS
   ↓
New Deployment
Monitoring

Application logs are collected using Amazon CloudWatch Logs.

Separate log groups are configured for:

Voting App
Result App
Worker
Project Outcome

This project demonstrates practical experience with:

Infrastructure as Code using Terraform
Containerization using Docker
AWS ECS/Fargate deployment
CI/CD using GitHub Actions
AWS IAM and OIDC authentication
Secure secret management
PostgreSQL and Redis integration
AWS networking and load balancing
CloudWatch monitoring


### One important thing


Don't add this:


```text
[svg](...)

Those appeared because the Markdown renderer interpreted your headings/diagram incorrectly when the content was pasted. The README above uses normal Markdown headings, bullets, and code blocks, so GitHub will render it properly.

give me a simple professional one with author no architecture

Absolutely. Here is a simple, professional README with an author section and no architecture diagram.

# AWS Voting App


A cloud-based voting application deployed on AWS using Terraform, Docker, ECS, and GitHub Actions.


## Features


- Containerized voting application using Docker
- AWS ECS Fargate deployment
- Amazon ECR for Docker images
- PostgreSQL database using Amazon RDS
- Redis using Amazon ElastiCache
- Application Load Balancer for application traffic
- Infrastructure provisioned using Terraform
- CI/CD automation using GitHub Actions
- Secure database credentials using AWS Secrets Manager
- CloudWatch logging


## Technologies


- AWS
- Terraform
- Docker
- Amazon ECS
- Amazon ECR
- Amazon RDS
- Amazon ElastiCache
- GitHub Actions
- PostgreSQL
- Redis
- .NET


## CI/CD


GitHub Actions automatically:


1. Builds the Docker images.
2. Pushes the images to Amazon ECR.
3. Authenticates with AWS using GitHub OIDC.
4. Updates the ECS services.
5. Starts a new ECS deployment.


## Infrastructure


Terraform is used to provision and manage the AWS infrastructure, including:


- VPC and Subnets
- Security Groups
- ECS Cluster and Services
- ECR Repositories
- RDS PostgreSQL
- ElastiCache Redis
- Application Load Balancer
- IAM Roles and Policies
- CloudWatch Logs
- Secrets Manager


## Deployment


Initialize Terraform:


```bash
terraform init

Validate the configuration:

terraform validate

Preview the changes:

terraform plan

Deploy the infrastructure:

terraform apply
Security
GitHub Actions uses OIDC authentication with AWS.
Database credentials are stored securely using AWS Secrets Manager.
ECS retrieves the PostgreSQL password from Secrets Manager.
IAM roles are used to provide required permissions.
Author

Dhaneshwari Nerti
