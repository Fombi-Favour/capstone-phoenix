resource "aws_security_group" "nodes" {
  name = "${var.project_name}-${var.environment}-nodes"
  description = "k3s cluster nodes - least-privilege ingress"
  vpc_id = var.vpc_id

  tags = {
    Name = "${var.project_name}-${var.environment}-nodes"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Ingress: HTTP (world)
resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.nodes.id
  description = "HTTP from world"
  from_port = 80
  to_port = 80
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}

# Ingress: HTTPS (world)
resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.nodes.id
  description = "HTTPS from world"
  from_port = 443
  to_port = 443
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}

# Ingress: SSH (admin only)
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.nodes.id
  description = "SSH - admin IP only"
  from_port = 22
  to_port = 22
  ip_protocol = "tcp"
  cidr_ipv4 = var.admin_cidr
}

# Ingress: EC2 Instance connect
data "aws_ec2_managed_prefix_list" "ec2_instance_connect" {
  name = "com.amazonaws.${data.aws_region.current.name}.ec2-instance-connect"
}
resource "aws_vpc_security_group_ingress_rule" "ec2_instance_connect" {
  security_group_id = aws_security_group.nodes.id
  description = "Instance connect"
  from_port = 22
  to_port = 22
  ip_protocol = "tcp"
  prefix_list_id = data.aws_ec2_managed_prefix_list.ec2_instance_connect.id
}

data "aws_region" "current" {}

# Ingress: Kubernetes API (VPC-internal only)
resource "aws_vpc_security_group_ingress_rule" "k8s_api" {
  security_group_id = aws_security_group.nodes.id
  description = "k3s API server - VPC internal only"
  from_port = 6443
  to_port = 6443
  ip_protocol = "tcp"
  cidr_ipv4 = var.vpc_cidr
}

# Ingress: k3s flannel VXLAN (UDP 8472, node-to-node)
resource "aws_vpc_security_group_ingress_rule" "flannel_vxlan" {
  security_group_id = aws_security_group.nodes.id
  description = "k3s flannel VXLAN - VPC internal"
  from_port = 8472
  to_port = 8472
  ip_protocol = "udp"
  cidr_ipv4 = var.vpc_cidr
}

# Ingress: k3s flannel VXLAN (TCP 10250, node-to-node)
resource "aws_vpc_security_group_ingress_rule" "kubelet" {
  security_group_id = aws_security_group.nodes.id
  description = "Kubelet API - VPC internal"
  from_port = 10250
  to_port = 10250
  ip_protocol = "tcp"
  cidr_ipv4 = var.vpc_cidr
}

# Ingress: NodePort range (VPC-internal; world access is via Ingress/443)
resource "aws_vpc_security_group_ingress_rule" "nodeport" {
  security_group_id = aws_security_group.nodes.id
  description = "NodePort range - VPC internal only"
  from_port = 30000
  to_port = 32767
  ip_protocol = "tcp"
  cidr_ipv4 = var.vpc_cidr
}

# Egress: all (nodes pull images, reach AWS APIs)
resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.nodes.id
  description = "Allow all outbound"
  ip_protocol = "-1"
  cidr_ipv4 = "0.0.0.0/0"
}
