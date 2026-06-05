resource "nebius_compute_v1_instance" "ray_vm" {
  parent_id = var.project_id
  name      = var.vm_name

  resources = {
    platform = var.vm_platform
    preset   = var.vm_preset
  }

  boot_disk = {
    attach_mode = "READ_WRITE"
    managed_disk = {
      name = "${var.vm_name}-boot"
      spec = {
        type           = "NETWORK_SSD"
        size_gibibytes = var.boot_disk_size_gb
        source_image_family = {
          image_family = var.image_family
        }
      }
    }
  }

  network_interfaces = [{
    name              = "eth0"
    subnet_id         = var.subnet_id
    ip_address        = {}
    public_ip_address = {}
  }]

  cloud_init_user_data = <<-EOT
    #cloud-config
    users:
      - name: ubuntu
        groups: sudo
        sudo: ALL=(ALL) NOPASSWD:ALL
        shell: /bin/bash
        ssh_authorized_keys:
          - ${var.ssh_public_key}
  EOT
}
