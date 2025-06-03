output "elk_vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnets_ips" {
  value = module.vpc.public_subnets
}

output "private_subnets_ips" {
  value = module.vpc.private_subnets
}
