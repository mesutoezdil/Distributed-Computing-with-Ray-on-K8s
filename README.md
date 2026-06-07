# Distributed Computing with Ray on K8s

Lab repo for *Cloud Native HPC and AI Infrastructure*, Chapter 6. Provisions a single VM, bootstraps k3s + KubeRay + Kueue, and runs a Monte Carlo option pricing simulation across 10 Ray workers.

Stack: OpenTofu, k3s, Ray 2.55.1, KubeRay 1.6.0, Kueue 0.17.0

The chapter contains the full walkthrough. The files here are what the chapter references.

## Repository layout

```
tofu/          OpenTofu config: creates 1 Ubuntu 22.04 VM on Nebius
scripts/
  00-auth.sh   Nebius only: exports IAM token, project_id, subnet_id
  10-bootstrap.sh  Installs k3s + KubeRay + Kueue on any Ubuntu VM
  99-teardown.sh   Destroys all Nebius resources
k8s/
  kueue-setup.yaml              ClusterQueue (14 CPU) + LocalQueue
  rayjob-montecarlo-smoke.yaml  Smoke test: 10 workers, 200 tasks
  rayjob-montecarlo.yaml        Full run: 100 workers, 2,000 tasks
app/
  price_option.py  Monte Carlo simulation (configurable via env vars)
diagrams/          Mermaid architecture diagrams (see diagrams/README.md)
```

## Prerequisites

- `kubectl` >= 1.31, `helm` >= 3.14, `jq`, SSH key pair
- Nebius users also need: OpenTofu >= 1.8, Nebius CLI authenticated, 16+ non-GPU vCPU quota in eu-north1

## Quickstart

**Step 1: Provision the VM (Nebius)**

```bash
git clone https://github.com/mesutoezdil/Distributed-Computing-with-Ray-on-K8s.git
cd Distributed-Computing-with-Ray-on-K8s

source scripts/00-auth.sh
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
cd tofu && tofu init && tofu apply && cd ..
```

Other providers: create any 16-vCPU Ubuntu 22.04 VM with a public IP, then skip to step 2.

**Step 2: Bootstrap**

```bash
./scripts/10-bootstrap.sh                  # Nebius: IP resolved automatically
VM_IP="1.2.3.4" ./scripts/10-bootstrap.sh  # other providers: pass the IP
```

Installs k3s, KubeRay 1.6.0, Kueue 0.17.0. Creates the `quant-team` namespace, queue objects, and mounts `price_option.py` as a ConfigMap. Kubeconfig saved to `~/.kube/ray-lab.yaml`.

**Step 3: Run the smoke test**

```bash
export KUBECONFIG=~/.kube/ray-lab.yaml
kubectl apply -f k8s/rayjob-montecarlo-smoke.yaml
kubectl -n quant-team get rayjob montecarlo-smoke -w
```

Expected output:

```
Estimated option price: 6.0398
Paths simulated: 200,000,000
Wall time: 2.0s on 10 CPUs
```

**Step 4: Tear down**

```bash
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
./scripts/99-teardown.sh
```

## Scope

This repo covers the **single-VM smoke test only**. The 100-worker full run in Chapter 6 requires a managed Kubernetes cluster with ~430 vCPU and a dedicated node group. `k8s/rayjob-montecarlo.yaml` is included for when that cluster is available; raise the Kueue quota to 500 CPU before applying it.
