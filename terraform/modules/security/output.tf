output "public_security_group_id" {
  value = module.public_subnets_security_group.security_group_id
}

output "private_security_group_id" {
  value = module.private_subnets_security_group.security_group_id
}
