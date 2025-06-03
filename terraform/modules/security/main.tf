module "public_subnets_security_group" {
  source              = "terraform-aws-modules/security-group/aws"
  name                = "security-group-for-public-subnets"
  vpc_id              = var.elk_vpc_id
  ingress_rules       = ["https-443-tcp", "http-80-tcp", "kibana-tcp", "ssh-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules        = ["all-all"]
  egress_cidr_blocks  = ["0.0.0.0/0"]
}

module "private_subnets_security_group" {
  source                                = "terraform-aws-modules/security-group/aws"
  name                                  = "security-group-for-private-subnets"
  vpc_id                                = var.elk_vpc_id
  ingress_with_source_security_group_id = [
    {
      rule                     = "https-443-tcp"
      source_security_group_id = module.public_subnets_security_group.security_group_id
    },
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.public_subnets_security_group.security_group_id
    },
    {
      rule                     = "elasticsearch-rest-tcp"
      source_security_group_id = module.public_subnets_security_group.security_group_id
    }
  ]
  ingress_with_cidr_blocks = [
    {
      rule        = "ssh-tcp"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}

