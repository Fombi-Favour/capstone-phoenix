output "vpc_id" {
  description = "VPC ID."
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value = module.network.public_subnet_ids
}

output "control_plane_public_ip" {
  description = "Public IP of the k3s control-plane node (for SSH + kubeconfig)"
  value = module.compute.control_plane_public_ip
}

output "control_plane_private_ip" {
  description = "Private IP of the k3s control-plane node (for worker join URL)."
  value = module.compute.control_plane_private_ip
}

output "worker_public_ips" {
  description = "Public IPs of all k3s worker nodes."
  value = module.compute.worker_public_ips
}

output "worker_private_ips" {
  description = "Private IPs of all k3s worker nodes."
  value = module.compute.worker_private_ips
}

output "ansible_inventory_hint" {
  description = <<-EOT
    Copy-pasteable hint for building your Ansible inventory.
    Pipe through: terraform output -raw ansible_inventory_hint > infra/ansible/inventory/hosts.ini
  EOT
  value = <<-EOT
[control_plane]
${module.compute.control_plane_public_ip} ansible_user=ubuntu

[workers]
${join("\n", formatlist("%s ansible_user=ubuntu", module.compute.worker_public_ips))}

[k3s_cluster:children]
control_plane
workers
  EOT
}
