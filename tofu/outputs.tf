output "vm_id" {
  description = "Compute instance ID — scripts/10-bootstrap.sh uses this to look up the public IP."
  value       = nebius_compute_v1_instance.ray_vm.id
}
