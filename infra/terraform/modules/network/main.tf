module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs = var.availability_zones
  public_subnets = var.public_subnet_cidrs

  enable_nat_gateway = false
  single_nat_gateway = false

  # auto assign public IPs on public subnets so every node is reachable
  map_public_ip_on_launch = true

  enable_dns_hostnames = true
  enable_dns_support = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}