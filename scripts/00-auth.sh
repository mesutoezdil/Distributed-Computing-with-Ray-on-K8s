#!/usr/bin/env bash
# Source this file: `source scripts/00-auth.sh`
# Exports the IAM token and Nebius resource IDs OpenTofu needs.
# Requires: nebius CLI (authenticated profile), jq.

set -u

command -v nebius >/dev/null || { echo "nebius CLI not found"; return 1 2>/dev/null || exit 1; }
command -v jq     >/dev/null || { echo "jq not found";         return 1 2>/dev/null || exit 1; }

# IAM token for the Nebius provider (short-lived; re-source when it expires).
NEBIUS_IAM_TOKEN="$(nebius iam get-access-token)"
export NEBIUS_IAM_TOKEN

# Project ID: taken from the active CLI profile.
# (OpenTofu reads TF_VAR_* environment variables, same convention.)
TF_VAR_project_id="$(nebius --format json profile get | jq -r '.parent_id')"
export TF_VAR_project_id

# Default subnet of the project. If you run multiple subnets, override
# TF_VAR_subnet_id manually after sourcing this script.
TF_VAR_subnet_id="$(nebius --format json vpc subnet list \
  --parent-id "$TF_VAR_project_id" | jq -r '.items[0].metadata.id')"
export TF_VAR_subnet_id

echo "project_id : $TF_VAR_project_id"
echo "subnet_id  : $TF_VAR_subnet_id"
echo "IAM token  : exported (NEBIUS_IAM_TOKEN)"
