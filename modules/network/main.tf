module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"
  name = var.vpc_name

  azs = var.azs
  public_subnets = var.public_subnets 
  private_subnets = var.private_subnets
  cidr = var.cidr
  enable_nat_gateway = true
  single_nat_gateway = true
  one_nat_gateway_per_az = false
  enable_dns_hostnames = true
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}
