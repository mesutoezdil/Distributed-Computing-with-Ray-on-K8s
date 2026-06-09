variable "project_id" {
  description = "Nebius project ID. Exported as TF_VAR_project_id by scripts/00-auth.sh."
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key injected into node cloud-init."
  type        = string
}

variable "k8s_version" {
  description = "Kubernetes control plane version."
  type        = string
  default     = "1.32"
}

variable "system_node_count" {
  description = "Fixed number of system nodes for control-plane workloads."
  type        = number
  default     = 2
}

variable "ray_min_nodes" {
  description = "Autoscaler minimum for the ray-compute node group."
  type        = number
  default     = 0
}

variable "ray_max_nodes" {
  description = "Autoscaler maximum for the ray-compute node group. Provider cap is 100. 100 nodes x 4 vCPU = 400 vCPU."
  type        = number
  default     = 100
}

variable "ray_node_preset" {
  description = "Compute preset for ray-compute nodes. 4vcpu-16gb = 4 vCPU per worker."
  type        = string
  default     = "4vcpu-16gb"
}
