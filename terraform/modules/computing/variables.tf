variable "ami_id" {
  type = string
  nullable = false
}

variable "kibana_instance_type" {
  type = string
  nullable = false
}

variable "elastic_instance_type" {
  type = string
  nullable = false
}

variable "baston_security_group_ids" {
  type = list(string)
  nullable = false
}

variable "elastic_security_group_ids" {
  type = list(string)
  nullable = false
}

variable "baston_key" {
  type = string
  nullable = false
}

variable "kibana_subnets" {
  type = list(string)
  nullable = false
}

variable "elastic_subnets" {
  type = list(string)
  nullable = false
}
