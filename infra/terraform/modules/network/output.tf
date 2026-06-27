output "vpc_id" {
  description = "ID of the created VPC."
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs (one per AZ)."
  value = module.vpc.public_subnets
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value = module.vpc.vpc_cidr_block
}
