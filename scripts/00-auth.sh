#!/usr/bin/env bash
# Source this file: `source scripts/00-auth.sh`
# Exports the IAM token and Nebius resource IDs OpenTofu needs.
# Requires: nebius CLI (authenticated profile), jq.

command -v nebius >/dev/null || { echo "nebius CLI not found"; return 1 2>/dev/null || exit 1; }
command -v jq     >/dev/null || { echo "jq not found";         return 1 2>/dev/null || exit 1; }

# IAM token (short-lived; re-source when it expires)
NEBIUS_IAM_TOKEN="$(nebius iam get-access-token)"
export NEBIUS_IAM_TOKEN

# Derive project_id and subnet_id from the first subnet in the account
_SUBNET_JSON="$(nebius vpc subnet list --format json)"
TF_VAR_subnet_id="$(echo "$_SUBNET_JSON"  | jq -r '.items[0].metadata.id')"
TF_VAR_project_id="$(echo "$_SUBNET_JSON" | jq -r '.items[0].metadata.parent_id')"
export TF_VAR_subnet_id
export TF_VAR_project_id
unset _SUBNET_JSON

echo "project_id : $TF_VAR_project_id"
echo "subnet_id  : $TF_VAR_subnet_id"
echo "IAM token  : exported (NEBIUS_IAM_TOKEN)"
