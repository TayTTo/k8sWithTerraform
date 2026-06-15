terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket = "daikin-state1"
    key    = "state/terraform.tfstate"
    region = "ap-southeast-1"
    use_lockfile = true
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
}

module "network" {
  source = "./modules/network/"
  vpc_name = var.vpc_name
  azs = var.azs
  cidr = var.cidr
  public_subnets = var.public_subnets
  private_subnets = var.private_subnets
}

module "eks" {
  source = "./modules/eks/"

  cluster_name        = var.cluster_name
  kubernetes_version  = var.kubernetes_version
  vpc_id              = module.network.k8s_vpc_id
  private_subnet_ids  = module.network.private_subnets_ips
  api_allowed_cidrs   = var.api_allowed_cidrs
  node_instance_types = [var.k8s_worker_type]

  tags = {
    Terraform = "true"
    Cluster   = var.cluster_name
  }
}

resource "aws_ecr_repository" "app" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

