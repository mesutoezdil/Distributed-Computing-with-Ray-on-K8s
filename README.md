# Distributed Computing with Ray on K8s

Lab repo for *Cloud Native HPC and AI Infrastructure*, Chapter 6. Provisions a single VM on Nebius, bootstraps k3s + KubeRay + Kueue inside it, and runs a Monte Carlo option pricing simulation across 10 Ray workers.

**Stack:** OpenTofu (MPL-2.0) · k3s · Ray 2.55.1 · KubeRay 1.6.0 · Kueue 0.17.0

All components are open source. The VM is created on Nebius via `tofu/` — swap it for any provider that gives you a 16-vCPU Ubuntu VM and everything else runs unchanged.

---

## Repository layout

```
tofu/
  versions.tf          OpenTofu and Nebius provider version pins
  providers.tf         Provider config (credentials read from env)
  variables.tf         All input variables with descriptions
  main.tf              1 resource: a 16-vCPU Ubuntu VM
  outputs.tf           Exports vm_id (used by bootstrap to resolve the public IP)

scripts/
  00-auth.sh           Fetches a Nebius IAM token and exports project_id + subnet_id
  10-bootstrap.sh      SSHes into the VM, installs k3s + KubeRay + Kueue, loads ConfigMap
  99-teardown.sh       Deletes all cloud resources

k8s/
  kueue-setup.yaml              ResourceFlavor + ClusterQueue (14 CPU quota) + LocalQueue
  rayjob-montecarlo-smoke.yaml  10 workers, 200 tasks — validates the full pipeline
  rayjob-montecarlo.yaml        100 workers, 2,000 tasks — for multi-node clusters

app/
  price_option.py      Monte Carlo simulation (scale controlled via env vars)
  Dockerfile           Optional: bake the script into an image
```

---

## Prerequisites

- OpenTofu >= 1.8 → https://opentofu.org/docs/intro/install/
- Nebius CLI installed and authenticated (`nebius profile create`)
- `jq`, `kubectl` >= 1.31, `helm` >= 3.14
- An SSH key pair (`~/.ssh/id_rsa` or ed25519 equivalent)
- Nebius project with at least 16 non-GPU vCPU quota in eu-north1

---

## Workflow

### 1. Clone and authenticate

```bash
git clone https://github.com/mesutoezdil/Distributed-Computing-with-Ray-on-K8s.git
cd Distributed-Computing-with-Ray-on-K8s
source scripts/00-auth.sh
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_rsa.pub)"
```

### 2. Provision the VM

```bash
cd tofu
tofu init
tofu plan
tofu apply     # creates 1 Ubuntu VM (~1-2 min)
cd ..
```

**What gets created:** 1× cpu-e2/16vcpu-64gb Ubuntu 22.04 VM with a public IP.

**Cost:** ~$0.10–0.20/hour while running. Stopped by `tofu destroy`.

### 3. Bootstrap k3s + KubeRay + Kueue

```bash
./scripts/10-bootstrap.sh
# - resolves VM public IP via Nebius CLI
# - installs k3s (single-node Kubernetes)
# - installs KubeRay 1.6.0 via Helm
# - installs Kueue v0.17.0
# - creates quant-team namespace and queue objects
# - loads price_option.py as a ConfigMap

export KUBECONFIG=~/.kube/ray-lab.yaml
```

### 4. Run the smoke test

```bash
kubectl apply -f k8s/rayjob-montecarlo-smoke.yaml
kubectl -n quant-team get rayjob montecarlo-smoke -w
kubectl -n quant-team logs -l job-name=montecarlo-smoke --tail=5
# Expected: price ~6.04, 200M paths
```

### 5. Tear everything down

```bash
./scripts/99-teardown.sh
```

---

## Cost summary

| State | Active resources | Duration |
|-------|-----------------|----------|
| VM running, no job | 1× 16-vCPU VM | Ongoing |
| Smoke test | same VM | ~5-10 min |
| After `tofu destroy` | Nothing | — |

---

## Scaling up

This setup runs on a single VM with k3s. To scale to a real multi-node cluster:
1. Replace `tofu/main.tf` with an MK8s cluster resource (see git history)
2. Update `scripts/10-bootstrap.sh` to use `nebius mk8s v1 cluster get-credentials`
3. Use `k8s/rayjob-montecarlo.yaml` for the 100-worker full run
