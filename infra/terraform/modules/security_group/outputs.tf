output "node_sg_id" {
  description = "Security group ID attached to every k3s node."
  value = aws_security_group.nodes.id
}
