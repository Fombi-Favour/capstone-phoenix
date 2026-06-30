variable "aws_region" {
  description = "AWS region to deploy into"
  type = string
  default = "eu-west-2"
}

variable "project_name" {
  description = "Project name used for resource naming and tags"
  type = string
  default = "taskapp"
}

variable "environment" {
  description = "Environmental label (dev / staging / prod)"
  type = string
  default = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "One public subnet CIDR per availability zone (at least 2)"
  type = list(string)
  default = [ "10.0.1.0/24", "10.0.2.0/24" ]
}

variable "availability_zones" {
  description = "AZs that corespond to public_subnet_cidrs"
  type = list(string)
  default = [ "eu-west-2a", "eu-west-2b" ]
}

variable "admin_cidr" {
  description = "The IP in CIDR notation that is allowed SSH access"
  type = string
  default = ""
}

variable "control_plane_instance_type" {
  description = "EC2 instance type for k3s control-panel node"
  type = string
  default = "t3.small"
}

variable "worker_instance_type" {
  description = "EC2 instance type for k3s worker nodes"
  type = string
  default = "t3.small"
}

variable "worker_count" {
  description = "Number of k3s worker (agent) nodes"
  type = number
  default = 2
}

variable "ami_id" {
  description = "EC2 AMI ID"
  type = string
  default = "ami-07f936ee1f9a0de0e" # Ubuntu 24.04 LTS
}

variable "key_pair_name" {
  description = "Name of an existing EC2 et Pair to use for SSH access"
  type = string
}
