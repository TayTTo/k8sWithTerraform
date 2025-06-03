terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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
  elk_vpc_id = module.network.elk_vpc_id
}

resource "aws_key_pair" "elk_keypair" {
  key_name = "elk-keypair"
  public_key = file(var.key_path)
}

module "computing" {
  source = "./modules/computing/"
  ami_id = var.ami_id
  elk_key = aws_key_pair.elk_keypair.key_name
  kibana_instance_type = var.kibana_instance_type
  kibana_security_group_ids = [module.security.public_security_group_id]
  elastic_instance_type = var.elastic_instance_type
  elastic_security_group_ids = [module.security.private_security_group_id]
  kibana_subnets = module.network.public_subnets_ips
  elastic_subnets = module.network.private_subnets_ips
}
