#!/usr/bin/env bash
# Bootstrap Nebius Managed K8s for the full 100-worker Ray run.
# Installs KubeRay 1.6.0 and Kueue v0.17.0, sets Kueue quota to 500 CPU / 900Gi,
# and loads the Monte Carlo source as a ConfigMap.
#
# Prerequisites:
#   source scripts/00-auth.sh        # sets NEBIUS_IAM_TOKEN
#   tofu -chdir=tofu/mk8s apply      # cluster must exist
#
# Usage:
#   bash scripts/20-bootstrap-mk8s.sh

set -euo pipefail

CLUSTER_ID="${CLUSTER_ID:-$(tofu -chdir=tofu/mk8s output -raw cluster_id)}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-$HOME/.kube/ray-mk8s.yaml}"
KUBERAY_VERSION="1.6.0"
KUEUE_VERSION="v0.17.0"

export KUBECONFIG="${KUBECONFIG_PATH}"

# --- 1. Kubeconfig --------------------------------------------------------------
echo ">>> Fetching kubeconfig for ${CLUSTER_ID}"
nebius mk8s cluster get-credentials \
  --id "${CLUSTER_ID}" \
  --external \
  --kubeconfig "${KUBECONFIG_PATH}" \
  --context-name ray-mk8s \
  --force
echo ">>> KUBECONFIG=${KUBECONFIG_PATH}"

# --- 2. Wait for system nodes ---------------------------------------------------
echo ">>> Waiting for nodes to be Ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s
kubectl get nodes -o wide

# --- 3. KubeRay operator --------------------------------------------------------
echo ">>> Installing KubeRay ${KUBERAY_VERSION}"
helm repo add kuberay https://ray-project.github.io/kuberay-helm/ --force-update >/dev/null
helm repo update >/dev/null
helm upgrade --install kuberay-operator kuberay/kuberay-operator \
  --version "${KUBERAY_VERSION}" \
  --namespace kuberay-system \
  --create-namespace \
  --wait

# --- 4. Kueue -------------------------------------------------------------------
echo ">>> Installing Kueue ${KUEUE_VERSION}"
kubectl apply --server-side -f \
  "https://github.com/kubernetes-sigs/kueue/releases/download/${KUEUE_VERSION}/manifests.yaml"
kubectl -n kueue-system rollout status deployment/kueue-controller-manager --timeout=300s

# --- 5. Namespace and queue objects ---------------------------------------------
echo ">>> Creating quant-team namespace"
kubectl create namespace quant-team --dry-run=client -o yaml | kubectl apply -f -

echo ">>> Applying Kueue setup (base quota)"
kubectl apply -f k8s/kueue-setup.yaml

echo ">>> Patching ClusterQueue quota for full 100-worker run (500 CPU / 900Gi)"
kubectl patch clusterqueue hpc-queue --type=merge -p '{
  "spec": {
    "resourceGroups": [{
      "coveredResources": ["cpu", "memory"],
      "flavors": [{
        "name": "default-flavor",
        "resources": [
          {"name": "cpu",    "nominalQuota": "500"},
          {"name": "memory", "nominalQuota": "900Gi"}
        ]
      }]
    }]
  }
}'

kubectl get clusterqueue hpc-queue

# --- 6. ConfigMap for Monte Carlo source ----------------------------------------
echo ">>> Publishing price_option.py as ConfigMap"
kubectl -n quant-team create configmap montecarlo-src \
  --from-file=app/price_option.py \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo ">>> Bootstrap complete."
echo "    KUBECONFIG=${KUBECONFIG_PATH}"
echo "    Next: kubectl apply -f k8s/rayjob-montecarlo.yaml"
