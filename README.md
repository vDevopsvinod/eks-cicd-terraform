# eks-cicd-terraform


EKS CI/CD Infrastructure Repository Setup Guide
Project Overview
This repository creates AWS EKS infrastructure using Terraform and GitHub Actions.
Infrastructure created:
•	VPC
•	Public and Private Subnets
•	Internet Gateway
•	IAM Roles
•	EKS Cluster
•	Managed Worker Nodes
•	S3 Backend for Terraform State
________________________________________
Repository Name
eks-cicd-terraform
________________________________________
Architecture
GitHub Actions
      ↓
Terraform
      ↓
S3 Backend
      ↓
AWS Infrastructure
      ↓
EKS Cluster
________________________________________
Step 1 — Create GitHub Repository
Create repository:
eks-cicd-terraform
________________________________________
Step 2 — Project Structure
eks-cicd-terraform/
│
├── terraform/
│   ├── provider.tf
│   ├── backend.tf
│   ├── variables.tf
│   ├── vpc.tf
│   ├── iam.tf
│   ├── eks.tf
│   ├── nodegroup.tf
│   └── outputs.tf
│
├── .github/
│   └── workflows/
│       └── deploy.yml
│
├── k8s/
│   ├── deployment.yaml
│   └── service.yaml
│
└── .gitignore
________________________________________
Step 3 — Install Required Tools
Install:
•	Terraform
•	AWS CLI
•	kubectl
•	Git
________________________________________
Step 4 — Configure AWS CLI
aws configure
Add:
•	AWS Access Key
•	AWS Secret Key
•	Region: us-east-1
________________________________________
Step 5 — Create S3 Backend Bucket
aws s3 mb s3://vinod-terraform-state-001 --region us-east-1
Enable versioning:
aws s3api put-bucket-versioning \
--bucket vinod-terraform-state-001 \
--versioning-configuration Status=Enabled
________________________________________
Step 6 — Create backend.tf
File:
terraform/backend.tf
Code:
terraform {
  backend "s3" {
    bucket = "vinod-terraform-state-001"
    key    = "eks/terraform.tfstate"
    region = "us-east-1"
  }
}
________________________________________
Step 7 — Create provider.tf
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
________________________________________
Step 8 — Create variables.tf
variable "aws_region" {
  default = "us-east-1"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}
________________________________________
Step 9 — Create VPC
Terraform file:
terraform/vpc.tf
Code:
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "eks-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "eks-igw"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1"
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/vinod-eks-cluster" = "shared"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-2"
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/vinod-eks-cluster" = "shared"
  }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "private-subnet-1"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/vinod-eks-cluster" = "shared"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "private-subnet-2"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/vinod-eks-cluster" = "shared"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_assoc_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}
________________________________________
Step 10 — Create IAM Roles
Terraform file:
terraform/iam.tf
Code:
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "eks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "ecr_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}
________________________________________
Step 11 — Create EKS Cluster
Terraform file:
terraform/eks.tf
Code:
resource "aws_eks_cluster" "eks" {
  name     = "vinod-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  version = "1.29"

  vpc_config {
    subnet_ids = [
      aws_subnet.public_1.id,
      aws_subnet.public_2.id,
      aws_subnet.private_1.id,
      aws_subnet.private_2.id
    ]

    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = {
    Name = "vinod-eks-cluster"
  }
}
________________________________________
Step 12 — Create Managed Node Group
Terraform file:
terraform/nodegroup.tf
Code:
resource "aws_eks_node_group" "workers" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "eks-workers"
  node_role_arn   = aws_iam_role.eks_node_role.arn

  subnet_ids = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  capacity_type = "ON_DEMAND"

  ami_type = "AL2_x86_64"

  disk_size = 20

  depends_on = [
    aws_iam_role_policy_attachment.worker_node_policy,
    aws_iam_role_policy_attachment.cni_policy,
    aws_iam_role_policy_attachment.ecr_policy
  ]

  tags = {
    Name = "eks-worker-nodes"
  }
}
________________________________________
Step 13 — Initialize Terraform
Go to terraform folder:
cd terraform
Run:
terraform init
________________________________________
Step 14 — Validate Terraform
terraform validate
________________________________________
Step 15 — Terraform Plan
terraform plan
________________________________________
Step 16 — Terraform Apply
terraform apply -auto-approve
________________________________________
Step 17 — Configure kubectl
aws eks update-kubeconfig \
--region us-east-1 \
--name vinod-eks-cluster
________________________________________
Step 18 — Verify Nodes
kubectl get nodes
Expected:
Ready
Ready
________________________________________
Step 19 — Create GitHub Actions Workflow
File:
.github/workflows/deploy.yml
Pipeline stages:
1.	Checkout code
2.	Configure AWS credentials
3.	Terraform init
4.	Terraform validate
5.	Terraform plan
6.	Terraform apply
7.	Configure kubectl
8.	Deploy Kubernetes manifests
________________________________________
Step 20 — Add GitHub Secrets
Go to:
GitHub Repo
→ Settings
→ Secrets and variables
→ Actions
Add:
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION
________________________________________
Step 21 — Push Code to GitHub
git add .
git commit -m "infra setup"
git push origin main
________________________________________
Step 22 — GitHub Actions Deployment
After push:
•	GitHub Actions runs automatically
•	Terraform creates infrastructure
•	EKS cluster deploys
•	Worker nodes created
________________________________________
Step 23 — Verify EKS Cluster
aws eks list-clusters --region us-east-1
________________________________________
Step 24 — Verify Kubernetes Pods
kubectl get pods -A
________________________________________
Step 25 — Destroy Infrastructure
terraform destroy -auto-approve
Or use GitHub Actions destroy workflow.
________________________________________
Important Files To Ignore
.gitignore
terraform/.terraform/
**/.terraform/*
*.tfstate
*.tfstate.*
*.tfvars
.venv/
________________________________________
Best Practices
•	Use S3 backend
•	Never upload tfstate files
•	Keep infrastructure and application repos separate
•	Use GitHub Secrets for credentials
•	Use remote backend for CI/CD
________________________________________
Recommended Next Project
Application deployment repository:
eks-app-deploy
Features:
•	Docker build
•	Push image to ECR
•	Deploy app to EKS
•	Kubernetes manifests
•	GitHub Actions CI/CD
________________________________________
Resume Project Title
CI/CD Automation for AWS EKS using Terraform and GitHub Actions
