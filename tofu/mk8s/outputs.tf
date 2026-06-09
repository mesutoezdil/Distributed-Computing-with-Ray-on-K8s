output "cluster_id" {
  description = "MK8s cluster ID — use as parent_id for node groups."
  value       = nebius_mk8s_v1_cluster.ray.id
}

output "public_endpoint" {
  description = "Kubernetes API public endpoint (https://<endpoint>/)."
  value       = nebius_mk8s_v1_cluster.ray.status.control_plane.endpoints.public_endpoint
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate (PEM) for kubeconfig."
  value       = nebius_mk8s_v1_cluster.ray.status.control_plane.auth.cluster_ca_certificate
  sensitive   = true
}
