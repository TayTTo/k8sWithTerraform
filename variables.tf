variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-1"
}

# ---------- Networking ----------

variable "vpc_name" {
  description = "Name for the VPC"
  type        = string
  default     = "eks-vpc"
}

variable "cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
}

variable "public_subnets" {
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "private_subnets" {
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

# ---------- EKS ----------

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "eks-cluster"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the control plane"
  type        = string
  default     = "1.33"
}

variable "k8s_worker_type" {
  description = "EC2 instance type for the managed node group"
  type        = string
  default     = "t3.medium"
}

variable "api_allowed_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint (your laptop/office IP)"
  type        = list(string)
  default     = ["0.0.0.0/0"] 
}

# ---------- ECR ----------

variable "ecr_repo_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "my-app"
}
