variable "project_id" {
  description = "Nebius project ID. Exported as TF_VAR_project_id by scripts/00-auth.sh."
  type        = string
}

variable "subnet_id" {
  description = "VPC subnet ID. Exported as TF_VAR_subnet_id by scripts/00-auth.sh."
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key injected via cloud-init. Export with: export TF_VAR_ssh_public_key=\"$(cat ~/.ssh/id_ed25519.pub)\""
  type        = string
}

variable "vm_name" {
  type    = string
  default = "ray-lab"
}

variable "vm_platform" {
  description = "CPU platform. cpu-e2 is available on most Nebius regions."
  type        = string
  default     = "cpu-e2"
}

variable "vm_preset" {
  description = "16 vCPU fits the smoke test (10 workers x 1 CPU + head 2 CPU + k3s overhead)."
  type        = string
  default     = "16vcpu-64gb"
}

variable "image_family" {
  description = "Boot image family for the VM."
  type        = string
  default     = "ubuntu-22-lts"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GiB."
  type        = number
  default     = 50
}
