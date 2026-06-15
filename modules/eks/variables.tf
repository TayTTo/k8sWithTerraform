variable "cluster_name" { type = string }
variable "kubernetes_version" { type = string } 
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }

variable "api_allowed_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"] 
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "tags" {
  type    = map(string)
  default = {}
}
