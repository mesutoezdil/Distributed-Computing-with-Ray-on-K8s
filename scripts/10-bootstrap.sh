#!/usr/bin/env bash
# Bootstrap the freshly provisioned cluster: kubeconfig, KubeRay 1.6.0,
# Kueue 0.17.0, namespaces, queue objects, and the simulation ConfigMap.
# Run from the repo root after `tofu apply`.

set -euo pipefail

KUBERAY_VERSION="1.6.0"
KUEUE_VERSION="v0.17.0"

# --- 1. Kubeconfig -----------------------------------------------------------
# Pattern from the Nebius solutions library: read the cluster ID from TF state.
CLUSTER_ID="$(tofu -chdir=tofu output -raw cluster_id)"
echo ">>> Fetching kubeconfig for cluster ${CLUSTER_ID}"
nebius mk8s v1 cluster get-credentials --id "${CLUSTER_ID}" --external

echo ">>> Waiting for nodes"
kubectl wait --for=condition=Ready nodes --all --timeout=300s
kubectl get nodes -o wide

# --- 2. KubeRay operator -----------------------------------------------------
echo ">>> Installing KubeRay operator ${KUBERAY_VERSION}"
helm repo add kuberay https://ray-project.github.io/kuberay-helm/ >/dev/null
helm repo update >/dev/null
helm upgrade --install kuberay-operator kuberay/kuberay-operator \
  --version "${KUBERAY_VERSION}" \
  --namespace kuberay-system \
  --create-namespace \
  --wait

# --- 3. Kueue ----------------------------------------------------------------
echo ">>> Installing Kueue ${KUEUE_VERSION}"
kubectl apply --server-side -f \
  "https://github.com/kubernetes-sigs/kueue/releases/download/${KUEUE_VERSION}/manifests.yaml"
kubectl -n kueue-system rollout status deployment/kueue-controller-manager --timeout=300s

# --- 4. Namespaces and queues ------------------------------------------------
echo ">>> Creating namespace and queue objects"
kubectl create namespace quant-team --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/kueue-setup.yaml

# --- 5. Simulation code as a ConfigMap ----------------------------------------
# The RayJobs mount this into the head pod, so no container registry is needed
# and the stock rayproject/ray image can be used as-is. (The book chapter bakes
# the script into an image instead; both are equivalent at runtime.)
echo ">>> Publishing price_option.py as a ConfigMap"
kubectl -n quant-team create configmap montecarlo-src \
  --from-file=app/price_option.py \
  --dry-run=client -o yaml | kubectl apply -f -

echo ">>> Bootstrap complete. Next:"
echo "    kubectl apply -f k8s/rayjob-montecarlo-smoke.yaml   # 10-worker validation"
echo "    kubectl apply -f k8s/rayjob-montecarlo.yaml         # full 100-worker run"
