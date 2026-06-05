# Distributed Computing with Ray on K8s

Lab repo for *Cloud Native HPC and AI Infrastructure*, Chapter 6. Provisions a single VM, bootstraps k3s + KubeRay + Kueue inside it, and runs a Monte Carlo option pricing simulation across 10 Ray workers.

**Stack:** OpenTofu (MPL-2.0) · k3s · Ray 2.55.1 · KubeRay 1.6.0 · Kueue 0.17.0

---

## How it works

The lab is split into two independent steps:

| Step | What it does | Provider-specific? |
|------|--------------|--------------------|
| **1. Provision VM** | Opens a 16-vCPU Ubuntu 22.04 VM with a public IP | Yes — `tofu/` targets Nebius. Swap for any provider. |
| **2. Bootstrap** | SSHes into the VM, installs k3s + KubeRay + Kueue | No — works on any Ubuntu VM, any cloud. |

If you already have a VM from AWS, GCP, or anywhere else, skip step 1 and go straight to step 2.

---

## Repository layout

```
tofu/
  main.tf              Creates 1 Ubuntu 22.04 VM on Nebius (swap for your provider)
  variables.tf         All input variables with descriptions
  versions.tf          OpenTofu and Nebius provider version pins
  providers.tf         Provider config (credentials read from env)
  outputs.tf           Exports vm_id (used by bootstrap to resolve the public IP)
  tofu.tfvars.example  Example variable values

scripts/
  00-auth.sh           Nebius only: fetches IAM token, exports project_id + subnet_id
  10-bootstrap.sh      Universal: installs k3s + KubeRay + Kueue on any Ubuntu VM
  99-teardown.sh       Deletes all Nebius resources via tofu destroy

k8s/
  kueue-setup.yaml              ResourceFlavor + ClusterQueue (14 CPU) + LocalQueue
  rayjob-montecarlo-smoke.yaml  10 workers, 200 tasks, 200M paths — full pipeline test
  rayjob-montecarlo.yaml        100 workers, 2,000 tasks — for multi-node clusters

app/
  price_option.py      Monte Carlo simulation (scale via NUM_TASKS / PATHS_PER_TASK env vars)
  Dockerfile           Optional: bake the script into an image
```

---

## Prerequisites

**Everyone:**
- `kubectl` >= 1.31, `helm` >= 3.14, `jq`
- An SSH key pair (`~/.ssh/id_ed25519` or equivalent)

**Nebius users only (step 1):**
- OpenTofu >= 1.8 → https://opentofu.org/docs/intro/install/
- Nebius CLI installed and authenticated (`nebius profile create`)
- Nebius project with at least 16 non-GPU vCPU quota in eu-north1

---

## Workflow

### Step 1 — Provision the VM (Nebius)

```bash
git clone https://github.com/mesutoezdil/Distributed-Computing-with-Ray-on-K8s.git
cd Distributed-Computing-with-Ray-on-K8s

source scripts/00-auth.sh
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"

cd tofu
tofu init
tofu apply     # creates 1 Ubuntu 22.04 VM (~1 min)
cd ..
```

**What gets created:** 1× cpu-e2/16vcpu-64gb VM, public IP, 50 GiB SSD disk.

**Cost:** ~$0.10–0.20/hour. Stopped by `./scripts/99-teardown.sh`.

> **Other providers:** Create any 16-vCPU Ubuntu 22.04 VM with a public IP and SSH access, then go to step 2.

---

### Step 2 — Bootstrap (any provider)

**Nebius users** — IP is resolved automatically from tofu state:

```bash
./scripts/10-bootstrap.sh
```

**Other providers** — pass the VM IP directly:

```bash
VM_IP="1.2.3.4" ./scripts/10-bootstrap.sh
```

This script installs on the VM:
1. **k3s** — single-node Kubernetes with correct TLS SAN for the public IP
2. **KubeRay 1.6.0** — Kubernetes operator for Ray clusters
3. **Kueue v0.17.0** — job queuing and quota management
4. **quant-team** namespace, queue objects, and simulation ConfigMap

Kubeconfig is saved to `~/.kube/ray-lab.yaml`.

```bash
export KUBECONFIG=~/.kube/ray-lab.yaml
kubectl get nodes
# NAME          STATUS   ROLES           AGE   VERSION
# ray-lab-vm    Ready    control-plane   1m    v1.35.x+k3s1
```

---

### Step 3 — Run the smoke test

```bash
kubectl apply -f k8s/rayjob-montecarlo-smoke.yaml
kubectl -n quant-team get rayjob montecarlo-smoke -w
kubectl -n quant-team logs -l job-name=montecarlo-smoke --tail=5
```

Expected output:
```
Estimated option price: 6.0398
Paths simulated: 200,000,000
Wall time: 2.1s on 10 CPUs
```

The estimated price converges near the Black-Scholes closed-form value of ~6.04.

---

### Step 4 — Tear everything down

```bash
./scripts/99-teardown.sh
```

---

## Cost summary

| State | Active resources | Cost |
|-------|-----------------|------|
| VM running, no job | 1× 16-vCPU VM | ~$0.10–0.20/hr |
| Smoke test running | same VM | ~5 min extra |
| After `tofu destroy` | Nothing | $0 |

---

## Scaling up

This setup runs on a single VM with k3s and validates the full pipeline end-to-end. To scale to a real multi-node cluster:

1. Replace `tofu/main.tf` with an MK8s cluster resource (or equivalent for your provider)
2. Update `scripts/10-bootstrap.sh` to fetch kubeconfig from the managed cluster
3. Increase worker replicas and CPU requests in the RayJob manifests
4. Use `k8s/rayjob-montecarlo.yaml` for the 100-worker full run (~430 vCPU required)
