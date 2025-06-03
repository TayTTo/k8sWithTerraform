module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name = var.vpc_name

  azs = var.azs
  public_subnets = var.public_subnets 
  private_subnets = var.private_subnets
  enable_nat_gateway = true
  single_nat_gateway = true
  one_nat_gateway_per_az = false
}
