output "control_plane_public_ip" {
  description = "Static Elastic IP of the control-plane node."
  value       = aws_eip.control_plane.public_ip
}

output "control_plane_private_ip" {
  description = "Private IP of the control-plane node (used by workers to join)."
  value = module.control_plane.private_ip
}

output "worker_public_ips" {
  description = "Public IPs of all worker nodes."
  value = [for w in module.workers : w.public_ip]
}

output "worker_private_ips" {
  description = "Private IPs of all worker nodes."
  value = [for w in module.workers : w.private_ip]
}

output "control_plane_instance_id" {
  description = "EC2 instance ID of the control-plane node."
  value = module.control_plane.id
}

output "worker_instance_ids" {
  description = "EC2 instance IDs of all worker nodes."
  value = { for k, w in module.workers : k => w.id }
}
