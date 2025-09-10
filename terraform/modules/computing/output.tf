output "controller_tag" {
  value = aws_launch_template.k8s_controller_asg_template.tags
}

output "worker_tag" {
  value = aws_launch_template.k8s_worker_asg_template.tags
}

output "baston_tag" {
  value = aws_launch_template.baston_host.tags
}
