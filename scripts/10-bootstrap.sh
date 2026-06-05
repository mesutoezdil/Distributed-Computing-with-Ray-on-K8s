#!/usr/bin/env bash
# Bootstrap a single-VM Ray lab: installs k3s, KubeRay, and Kueue on the VM
# created by tofu, then loads the simulation code as a ConfigMap.
# Run from the repo root after `tofu apply`.

set -euo pipefail

KUBERAY_VERSION="1.6.0"
KUEUE_VERSION="v0.17.0"
SSH_USER="${SSH_USER:-ubuntu}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-$HOME/.kube/ray-lab.yaml}"

# --- 1. Resolve VM public IP -------------------------------------------------
VM_ID="$(tofu -chdir=tofu output -raw vm_id)"
echo ">>> Resolving public IP for VM ${VM_ID}"
VM_IP="$(nebius compute v1 instance get --id "${VM_ID}" --format json \
  | jq -r '.status.network_interfaces[0].public_ip_address.address')"
echo ">>> VM public IP: ${VM_IP}"

# --- 2. Wait for SSH ----------------------------------------------------------
echo ">>> Waiting for SSH to become available..."
until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
    "${SSH_USER}@${VM_IP}" true 2>/dev/null; do
  sleep 5
done
echo ">>> SSH ready"

# --- 3. Install k3s -----------------------------------------------------------
echo ">>> Installing k3s"
ssh -o StrictHostKeyChecking=no "${SSH_USER}@${VM_IP}" \
  'curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" sh -s -'

# --- 4. Fetch kubeconfig ------------------------------------------------------
echo ">>> Fetching kubeconfig"
mkdir -p "$(dirname "${KUBECONFIG_PATH}")"
ssh "${SSH_USER}@${VM_IP}" 'sudo cat /etc/rancher/k3s/k3s.yaml' \
  | sed "s/127.0.0.1/${VM_IP}/g" > "${KUBECONFIG_PATH}"
export KUBECONFIG="${KUBECONFIG_PATH}"
echo ">>> KUBECONFIG=${KUBECONFIG_PATH}"

kubectl wait --for=condition=Ready nodes --all --timeout=120s
kubectl get nodes -o wide

# --- 5. KubeRay operator ------------------------------------------------------
echo ">>> Installing KubeRay ${KUBERAY_VERSION}"
helm repo add kuberay https://ray-project.github.io/kuberay-helm/ >/dev/null
helm repo update >/dev/null
helm upgrade --install kuberay-operator kuberay/kuberay-operator \
  --version "${KUBERAY_VERSION}" \
  --namespace kuberay-system \
  --create-namespace \
  --wait

# --- 6. Kueue -----------------------------------------------------------------
echo ">>> Installing Kueue ${KUEUE_VERSION}"
kubectl apply --server-side -f \
  "https://github.com/kubernetes-sigs/kueue/releases/download/${KUEUE_VERSION}/manifests.yaml"
kubectl -n kueue-system rollout status deployment/kueue-controller-manager --timeout=300s

# --- 7. Namespace, queue, ConfigMap -------------------------------------------
echo ">>> Creating namespace and queue objects"
kubectl create namespace quant-team --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/kueue-setup.yaml

echo ">>> Publishing price_option.py as ConfigMap"
kubectl -n quant-team create configmap montecarlo-src \
  --from-file=app/price_option.py \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo ">>> Bootstrap complete."
echo "    Add to your shell: export KUBECONFIG=${KUBECONFIG_PATH}"
echo "    Then run:          kubectl apply -f k8s/rayjob-montecarlo-smoke.yaml"
