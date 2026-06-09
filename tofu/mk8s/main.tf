resource "nebius_vpc_v1_network" "mk8s" {
  provider  = nebius.eu-west1
  parent_id = var.project_id
  name      = "mk8s-network"
}

resource "nebius_vpc_v1_subnet" "mk8s" {
  provider   = nebius.eu-west1
  parent_id  = var.project_id
  name       = "mk8s-subnet"
  network_id = nebius_vpc_v1_network.mk8s.id

  ipv4_private_pools = {
    use_network_pools = true
  }
  ipv4_public_pools = {
    use_network_pools = true
  }
}

resource "nebius_mk8s_v1_cluster" "ray" {
  provider  = nebius.eu-west1
  parent_id = var.project_id
  name      = "ray-cluster"

  control_plane = {
    subnet_id = nebius_vpc_v1_subnet.mk8s.id
    version   = var.k8s_version
    endpoints = {
      public_endpoint = {}
    }
  }
}

resource "nebius_mk8s_v1_node_group" "system" {
  provider  = nebius.eu-west1
  parent_id = nebius_mk8s_v1_cluster.ray.id
  name      = "system"

  fixed_node_count = var.system_node_count

  template = {
    resources = {
      platform = "cpu-e2"
      preset   = "8vcpu-32gb"
    }
    boot_disk = {
      type           = "NETWORK_SSD"
      size_gibibytes = 64
    }
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
    network_interfaces = [{
      public_ip_address = {}
    }]
  }
}

resource "nebius_mk8s_v1_node_group" "ray_compute" {
  provider  = nebius.eu-west1
  parent_id = nebius_mk8s_v1_cluster.ray.id
  name      = "ray-compute"

  autoscaling = {
    min_node_count = var.ray_min_nodes
    max_node_count = var.ray_max_nodes
  }

  template = {
    resources = {
      platform = "cpu-e2"
      preset   = var.ray_node_preset
    }
    boot_disk = {
      type           = "NETWORK_SSD"
      size_gibibytes = 64
    }
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
    network_interfaces = [{
      public_ip_address = {}
    }]
    taints = [{
      key    = "workload/ray"
      value  = "ray"
      effect = "NO_SCHEDULE"
    }]
    metadata = {
      labels = {
        "node-role" = "ray-compute"
      }
    }
  }
}
