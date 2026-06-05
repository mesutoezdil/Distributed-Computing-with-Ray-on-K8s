#!/usr/bin/env bash
# Tear down the Ray lab VM and all associated Nebius resources.

set -euo pipefail

# Delete Ray workloads if kubeconfig is available
if [ -f "${KUBECONFIG:-$HOME/.kube/ray-lab.yaml}" ]; then
  export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/ray-lab.yaml}"
  echo ">>> Deleting Ray workloads"
  kubectl -n quant-team delete rayjob --all --ignore-not-found=true || true
fi

echo ">>> Destroying infrastructure"
source scripts/00-auth.sh
tofu -chdir=tofu destroy -auto-approve

echo ">>> Done."
