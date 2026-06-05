# Distributed Computing with Ray on K8s

Lab repo for *Cloud Native HPC and AI Infrastructure*, Chapter 6. Provisions a single VM, bootstraps k3s + KubeRay + Kueue inside it, and runs a Monte Carlo option pricing simulation across 10 Ray workers.

Stack: OpenTofu (MPL-2.0), k3s, Ray 2.55.1, KubeRay 1.6.0, Kueue 0.17.0

The lab has two steps. Step 1 creates a VM and is provider-specific. Step 2 runs on the VM and works on any cloud. If you already have a 16-vCPU Ubuntu 22.04 VM with SSH access, skip step 1 and go directly to step 2.

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
  rayjob-montecarlo-smoke.yaml  10 workers, 200 tasks, 200M paths
  rayjob-montecarlo.yaml        100 workers, 2,000 tasks (multi-node clusters)

app/
  price_option.py      Monte Carlo simulation (scale via NUM_TASKS / PATHS_PER_TASK)
  Dockerfile           Optional: bake the script into an image
```

---

## Prerequisites

Everyone needs: `kubectl` >= 1.31, `helm` >= 3.14, `jq`, and an SSH key pair.

Nebius users also need: OpenTofu >= 1.8, Nebius CLI authenticated, at least 16 non-GPU vCPU quota in eu-north1.

---

## Workflow

### Step 1: Provision the VM (Nebius)

```bash
git clone https://github.com/mesutoezdil/Distributed-Computing-with-Ray-on-K8s.git
cd Distributed-Computing-with-Ray-on-K8s

source scripts/00-auth.sh
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"

cd tofu && tofu init && tofu apply
cd ..
```

Creates 1x cpu-e2/16vcpu-64gb VM with a public IP and 50 GiB SSD disk. Costs roughly $0.10-0.20/hour while running.

Other providers: create any 16-vCPU Ubuntu 22.04 VM with a public IP, then proceed to step 2.

### Step 2: Bootstrap (any provider)

Nebius users, run:

```bash
./scripts/10-bootstrap.sh
```

Other providers, pass the VM IP:

```bash
VM_IP="1.2.3.4" ./scripts/10-bootstrap.sh
```

The script SSHes into the VM and installs k3s (single-node Kubernetes), KubeRay 1.6.0, and Kueue v0.17.0. It also creates the `quant-team` namespace, queue objects, and loads `price_option.py` as a ConfigMap. Kubeconfig is saved to `~/.kube/ray-lab.yaml`.

```bash
export KUBECONFIG=~/.kube/ray-lab.yaml
kubectl get nodes
```

### Step 3: Run the smoke test

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

The price converges near the Black-Scholes closed-form value of ~6.04.

### Step 4: Tear everything down

```bash
./scripts/99-teardown.sh
```

---

## Cost summary

| State | Resources | Cost |
|-------|-----------|------|
| VM running, no job | 1x 16-vCPU VM | ~$0.10-0.20/hr |
| Smoke test | same VM | ~5 min extra |
| After tofu destroy | nothing | $0 |

---

## Scaling up

This setup validates the full pipeline on a single VM. To scale to a real multi-node cluster, replace `tofu/main.tf` with a managed Kubernetes resource, update the bootstrap script to fetch credentials from the cluster, and use `k8s/rayjob-montecarlo.yaml` for the 100-worker run (requires ~430 vCPU quota).
