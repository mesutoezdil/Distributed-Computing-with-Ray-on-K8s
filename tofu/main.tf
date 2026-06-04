# MK8s cluster and 2 node groups for the Ray Monte Carlo lab.
#
# Field nesting verified against the official working examples in
# https://github.com/nebius/nebius-solutions-library (k8s-training and
# applications/osmo modules): control_plane block, template.boot_disk
# (size_gibibytes/type), template.resources (platform/preset),
# template.network_interfaces, taints with effect "NO_SCHEDULE", and the
# autoscaling XOR fixed_node_count constraint.

resource "nebius_mk8s_v1_cluster" "ray_lab" {
  parent_id = var.project_id
  name      = var.cluster_name

  control_plane = {
    version   = var.k8s_version
    subnet_id = var.subnet_id

    # Public endpoint so kubectl/helm work from your workstation.
    # For private-only access, replace with your bastion setup.
    endpoints = {
      public_endpoint = {}
    }
  }
}

# -----------------------------------------------------------------------------
# System node group: fixed size, untainted.
# Hosts the KubeRay operator, Kueue, CoreDNS, and the Ray head pod
# (the head carries no toleration in the k8s/ manifests, so it lands here).
# -----------------------------------------------------------------------------
resource "nebius_mk8s_v1_node_group" "system" {
  parent_id = nebius_mk8s_v1_cluster.ray_lab.id
  name      = "system"
  version   = var.k8s_version

  fixed_node_count = var.system_node_count

  labels = {
    "node-role" = "system"
  }

  template = {
    resources = {
      platform = var.system_platform
      preset   = var.system_preset
    }

    boot_disk = {
      type           = "NETWORK_SSD"
      size_gibibytes = var.boot_disk_size_gb
    }

    network_interfaces = [
      {
        subnet_id         = var.subnet_id
        public_ip_address = var.nodes_public_ips ? {} : null
      }
    ]
  }
}

# -----------------------------------------------------------------------------
# Ray compute node group: tainted workload/ray=true:NO_SCHEDULE, scale-to-zero.
# Only pods carrying the matching toleration (the Ray workers in
# k8s/rayjob-montecarlo*.yaml, which tolerate via operator: Exists) schedule
# here. Mirrors "Step 1: provision the compute capacity" in the book chapter.
# -----------------------------------------------------------------------------
resource "nebius_mk8s_v1_node_group" "ray_compute" {
  parent_id = nebius_mk8s_v1_cluster.ray_lab.id
  name      = "ray-compute"
  version   = var.k8s_version

  # Exactly one of fixed_node_count / autoscaling may be set (provider constraint).
  fixed_node_count = var.ray_autoscaling_enabled ? null : var.ray_max_nodes

  autoscaling = var.ray_autoscaling_enabled ? {
    min_node_count = var.ray_min_nodes
    max_node_count = var.ray_max_nodes
  } : null

  labels = {
    "node-role" = "ray-compute"
  }

  template = {
    taints = [
      {
        key    = "workload/ray"
        value  = "true"
        effect = "NO_SCHEDULE"
      }
    ]

    resources = {
      platform = var.ray_platform
      preset   = var.ray_preset
    }

    boot_disk = {
      type           = "NETWORK_SSD"
      size_gibibytes = var.boot_disk_size_gb
    }

    network_interfaces = [
      {
        subnet_id         = var.subnet_id
        public_ip_address = var.nodes_public_ips ? {} : null
      }
    ]
  }
}
