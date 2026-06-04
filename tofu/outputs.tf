output "cluster_id" {
  description = "MK8s cluster ID; scripts/10-bootstrap.sh uses it for get-credentials."
  value       = nebius_mk8s_v1_cluster.ray_lab.id
}

output "cluster_name" {
  value = nebius_mk8s_v1_cluster.ray_lab.name
}

output "ray_compute_node_group_id" {
  value = nebius_mk8s_v1_node_group.ray_compute.id
}
