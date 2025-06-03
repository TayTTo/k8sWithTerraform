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
