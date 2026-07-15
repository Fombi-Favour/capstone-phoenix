locals {
  # Cycle through subnets to spread workers across AZs
  worker_subnets = [
    for i in range(var.worker_count) :
    var.public_subnet_ids[i % length(var.public_subnet_ids)]
  ]

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Allocate a static Elastic IP for the control plane
resource "aws_eip" "control_plane" {
  domain   = "vpc"
  instance = module.control_plane.id

  tags = {
    Name = "${var.project_name}-${var.environment}-control-plane-eip"
  }
}

# control-plane node
module "control_plane" {
  source = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 5.0"

  name = "${var.project_name}-${var.environment}-control-pane"

  ami = var.ami_id
  instance_type = var.control_plane_instance_type
  key_name = var.key_pair_name
  subnet_id = var.public_subnet_ids[0]
  vpc_security_group_ids = [var.node_security_group_id]
  associate_public_ip_address = true

  # Minimal user-data: set hostname so kubectl node names are meaningful
  user_data = <<-EOF
    #!/bin/bash
    hostnamectl set-hostname ${var.project_name}-control-plane
  EOF

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-control-plane"
    Role = "control-plane"
  })
}

# worker nodes
module "workers" {
  source = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 5.0"

  # for_each so each worker is an inepennet resource
  for_each = { for i in range(var.worker_count) : "worker-${i + 1}" => i }

  name = "${var.project_name}-${var.environment}-${each.key}"

  ami = var.ami_id
  instance_type = var.worker_instance_type
  key_name = var.key_pair_name
  subnet_id = local.worker_subnets[each.value]
  vpc_security_group_ids = [var.node_security_group_id]
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    hostnamectl set-hostname ${var.project_name}-${each.key}
  EOF

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-${each.key}"
    Role = "worker"
  })
}