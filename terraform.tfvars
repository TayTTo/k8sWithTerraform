region = "ap-southeast-1"

vpc_name        = "eks-vpc"
cidr            = "10.0.0.0/16"
azs             = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]

cluster_name       = "eks-cluster"
kubernetes_version = "1.33"
k8s_worker_type    = "t3.medium"

ecr_repo_name = "my-app"
