terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
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

module "security" {
  source = "./modules/security/"
  k8s_vpc_id = module.network.k8s_vpc_id
}

resource "aws_key_pair" "k8s_keypair" {
  key_name = "k8s-keypair"
  public_key = file(var.key_path)
}

module "computing" {
  source = "./modules/computing/"
  ami_id = var.ami_id
  k8s_key = aws_key_pair.k8s_keypair.key_name
  baston_instance_type = var.baston_instance_type
  baston_security_group_ids = [module.security.public_security_group_id]
  k8s_controller_type = var.k8s_controller_type
  k8s_worker_type = var.k8s_worker_type
  k8s_security_group_ids = [module.security.private_security_group_id]
  baston_subnets = module.network.public_subnets_ips
  k8s_subnets = module.network.private_subnets_ips
}
