variable "ami_id" {
  type = string
  nullable = false
}

variable "baston_instance_type" {
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

variable "baston_security_group_ids" {
  type = list(string)
  nullable = false
}

variable "k8s_security_group_ids" {
  type = list(string)
  nullable = false
}

variable "k8s_key" {
  type = string
  nullable = false
}

variable "baston_subnets" {
  type = list(string)
  nullable = false
}

variable "k8s_subnets" {
  type = list(string)
  nullable = false
}
