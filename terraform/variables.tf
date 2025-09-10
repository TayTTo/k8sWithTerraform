variable "region" {
  type = string
  nullable = false
}

variable "vpc_name" {
  type = string
}

variable "cidr" {
  type = string
}

variable "azs" {
  type = set(string)
}

variable "public_subnets" {
  type = set(string)
}

variable "private_subnets" {
  type = set(string)
}

variable "baston_instance_type" {
  type = string
  nullable = false
}

variable "ami_id" {
  type = string
  nullable = false
}

variable "k8s_controller_type" {
  type = string
  nullable = false
}

variable "k8s_worker_type" {
  type = string
  nullable = false
}
variable "key_path" {
  type = string
}
