output "kibana_tag" {
  value = aws_launch_template.kibana_asg_template.tags
}

output "elastic_tag" {
  value = aws_launch_template.elastic_asg_template.tags
}
