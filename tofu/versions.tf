# OpenTofu reads the same configuration block names as its predecessor, so
# the block below is named "terraform" even though the binary is `tofu`.
# Provider source per Nebius docs:
# https://docs.nebius.com/terraform-provider/quickstart
# OpenTofu resolves provider sources by hostname, so a provider hosted on a
# vendor registry like the one below installs the same way as registry ones.
terraform {
  required_version = ">= 1.8"

  required_providers {
    nebius = {
      source  = "terraform-provider.storage.eu-north1.nebius.cloud/nebius/nebius"
      version = ">= 0.5.55"
    }
  }
}
