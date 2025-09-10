resource "aws_launch_template" "baston_host" {
  name = "baston-asg"
  image_id = var.ami_id
  key_name = var.k8s_key
  network_interfaces {
    device_index = 0
    associate_public_ip_address = true
    security_groups = var.baston_security_group_ids
  }
  instance_type = var.baston_instance_type
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "baston_node"
      Role = "baston"
    }
  }
}

resource "aws_launch_template" "k8s_controller_asg_template" {
  name = "k8s-controller-auto-scaling-group"
  key_name = var.k8s_key
  image_id = var.ami_id
  instance_type = var.k8s_controller_type
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "k8s_controller_node"
      Role = "k8s_controller"
    }
  }
  vpc_security_group_ids = var.k8s_security_group_ids
}

resource "aws_launch_template" "k8s_worker_asg_template" {
  name = "k8s-worker-auto-scaling-group"
  key_name = var.k8s_key
  image_id = var.ami_id
  instance_type = var.k8s_worker_type
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "k8s_worker_node"
      Role = "k8s_worker"
    }
  }
  vpc_security_group_ids = var.k8s_security_group_ids
}

resource "aws_autoscaling_group" "baston_asg" {
  min_size = 1
  max_size = 2
  desired_capacity = 1
  launch_template {
    id = aws_launch_template.baston_host.id
  }
  vpc_zone_identifier = var.baston_subnets
}

resource "aws_autoscaling_group" "k8s_controller_asg" {
  min_size = 1
  max_size = 2
  desired_capacity = 1
  launch_template {
    id = aws_launch_template.k8s_controller_asg_template.id
  }
  vpc_zone_identifier = var.k8s_subnets
}

resource "aws_autoscaling_group" "k8s_worker_asg" {
  min_size = 1
  max_size = 2
  desired_capacity = 1
  launch_template {
    id = aws_launch_template.k8s_worker_asg_template.id
  }
  vpc_zone_identifier = var.k8s_subnets
}
