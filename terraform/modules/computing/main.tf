resource "aws_launch_template" "baston_host" {
  name = "baston-asg"
  image_id = var.ami_id
  key_name = var.baston_key
  network_interfaces {
    device_index = 0
    associate_public_ip_address = true
    security_groups = var.baston_security_group_ids
  }
  instance_type = var.kibana_instance_type
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "kibana_node"
      Role = "kibana"
    }
  }
}

resource "aws_launch_template" "elastic_asg_template" {
  name = "elastic-auto-scaling-group"
  key_name = var.baston_key
  image_id = var.ami_id
  instance_type = var.elastic_instance_type
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "elastic_node"
      Role = "elastic"
    }
  }
  vpc_security_group_ids = var.elastic_security_group_ids
}

resource "aws_autoscaling_group" "kibana_asg" {
  min_size = 1
  max_size = 2
  desired_capacity = 1
  launch_template {
    id = aws_launch_template.kibana_asg_template.id
  }
  vpc_zone_identifier = var.kibana_subnets
}

resource "aws_autoscaling_group" "elastic_asg" {
  min_size = 1
  max_size = 2
  desired_capacity = 1
  launch_template {
    id = aws_launch_template.elastic_asg_template.id
  }
  vpc_zone_identifier = var.elastic_subnets
}

locals {
  elastic_header_subnet_map = { for idx, value in var.elastic_subnets : idx => value}
}

resource "aws_instance" "elastic_header_node" {
  for_each = local.elastic_header_subnet_map
  instance_type = var.elastic_instance_type
  ami = var.ami_id
  key_name = var.elk_key
  subnet_id = each.value
  vpc_security_group_ids = var.elastic_security_group_ids
  tags = {
    Name = "elastic_header_${each.key}"
    Role = "elastic"
  }
}
