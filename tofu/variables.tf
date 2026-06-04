variable "project_id" {
  description = "Nebius project ID (parent container for all resources). Exported as TF_VAR_project_id by scripts/00-auth.sh."
  type        = string
}

variable "subnet_id" {
  description = "VPC subnet ID for cluster nodes. Exported as TF_VAR_subnet_id by scripts/00-auth.sh (default subnet of the project)."
  type        = string
}

variable "cluster_name" {
  description = "Name of the MK8s cluster."
  type        = string
  default     = "ray-montecarlo"
}

variable "k8s_version" {
  description = "Kubernetes control plane version. Chapter requires 1.31+."
  type        = string
  default     = "1.31"
}

# --- System node group: runs KubeRay/Kueue operators and the Ray head pod ---

variable "system_platform" {
  description = "CPU platform for system nodes."
  type        = string
  default     = "cpu-d3"
}

variable "system_preset" {
  description = "Resource preset for system nodes. 8vcpu-32gb fits the operators plus a 2vCPU/8Gi Ray head with room to spare."
  type        = string
  default     = "8vcpu-32gb"
}

variable "system_node_count" {
  description = "Fixed size of the system node group."
  type        = number
  default     = 2
}

# --- Ray compute node group: tainted, autoscaled, scale-to-zero ---

variable "ray_platform" {
  description = "CPU platform for Ray worker nodes."
  type        = string
  default     = "cpu-e2"
}

variable "ray_preset" {
  description = "Resource preset for Ray worker nodes. 16vcpu-64gb fits 3 chapter-sized workers (4vCPU/8Gi) per node with headroom for daemonsets."
  type        = string
  default     = "16vcpu-64gb"
}

variable "ray_autoscaling_enabled" {
  description = "true: node group autoscales min..max on pending pods. false: fixed at ray_max_nodes (use this for the benchmark run so node provisioning latency stays out of the measurement)."
  type        = bool
  default     = true
}

variable "ray_min_nodes" {
  description = "Minimum Ray compute nodes when autoscaling. 0 means you pay nothing between runs."
  type        = number
  default     = 0
}

variable "ray_max_nodes" {
  description = "Maximum Ray compute nodes. 36 x 16 vCPU = 576 vCPU ceiling; the 100-worker job needs ~34 nodes (3 workers per node)."
  type        = number
  default     = 36
}

variable "boot_disk_size_gb" {
  description = "Boot disk size per node in GiB. Ray spills objects to local disk under memory pressure; don't go below 96."
  type        = number
  default     = 128
}

variable "nodes_public_ips" {
  description = "Assign public IPv4 addresses to nodes. Required for pulling images from public registries (Docker Hub, GHCR) unless your subnet has NAT egress configured. Set false if you route egress another way."
  type        = bool
  default     = true
}
