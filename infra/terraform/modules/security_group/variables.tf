variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
  description = "VPC to place the security group in."
}

variable "vpc_cidr" {
  type = string
  description = "VPC CIDR used to scope cluster-internal rules."
}

variable "admin_cidr" {
  type = string
  description = "Your IP in CIDR notation — the only source allowed on port 22."
}
