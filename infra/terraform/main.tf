terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = ""
    key = ""
    region = ""
    dynamodb_table = ""
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project = var.project_name
      Environment = var.environment
      ManagedBy = "Terraform"
    }
  }
}

module "network" {
  source = "./modules/network"

  project_name = var.project_name
  environment = var.environment
  vpc_cidr = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  availability_zones = var.availability_zones
}

module "security_group" {
  source = "./modules/security_group"

  project_name = var.project_name
  environment = var.environment
  vpc_id = module.network.vpc_id
  vpc_cidr = var.vpc_cidr
  admin_cidr = var.admin_cidr
}

module "compute" {
  source = "./modules/compute"

  project_name = var.project_name
  environment = var.environment
  ami_id = var.amd_id
  key_pair_name = var.key_pair_name
  control_plane_instance_type = var.control_panel_instance_type
  worker_instance_type = var.worker_instance_type
  worker_count = var.worker_count
  
  # spread noes across subnets / AZs
  public_subnet_ids = module.network.public_subnet_ids
  node_security_group_id = module.security_group.node_sg_id
}