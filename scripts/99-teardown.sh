#!/usr/bin/env bash
# Tear everything down. Deletes Ray workloads first so the autoscaled node
# group drains, then destroys all Nebius resources via OpenTofu.

set -euo pipefail

echo ">>> Deleting Ray workloads (ignore not-found errors on a clean cluster)"
kubectl -n quant-team delete rayjob --all --ignore-not-found=true || true

echo ">>> Destroying infrastructure"
tofu -chdir=tofu destroy

echo ">>> Done. Verify in the Nebius console that no node groups remain."
