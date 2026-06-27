variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "ami_id" {
  type = string
  description = "AMI to use for all nodes (resolved by root module)."
}

variable "key_pair_name" {
  type = string
  description = "Existing EC2 Key Pair name."
}

variable "control_plane_instance_type" {
  type = string
  default = "t3.small"
}

variable "worker_instance_type" {
  type = string
  default = "t3.small"
}

variable "worker_count" {
  type = number
  default = 2
}

# variable "root_volume_size_gb" {
#   type = number
#   default = 20
# }

variable "public_subnet_ids" {
  type = list(string)
  description = "Subnet IDs (from network module) to place nodes into."
}

variable "node_security_group_id" {
  type = string
  description = "SG ID (from security_group module) to attach to every node."
}
