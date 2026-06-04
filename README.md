# Distributed Computing with Ray on K8s

Lab repo for *Cloud Native HPC and AI Infrastructure*, Chapter 6. Spins up a Kubernetes cluster on Nebius, installs KubeRay and Kueue, and runs a 2-billion-path Monte Carlo simulation across 100 Ray workers.

**Stack:** OpenTofu (MPL-2.0) · Ray 2.55.1 · KubeRay 1.6.0 · Kueue 0.17.0 · Kubernetes 1.31+

All components are open source. Manifests in `k8s/` are vendor-neutral; only `tofu/` is Nebius-specific — swap it for your provider's equivalent and everything else runs unchanged.

---

## Repository layout

```
tofu/
  versions.tf          OpenTofu and Nebius provider version pins
  providers.tf         Provider config (credentials read from env)
  variables.tf         All input variables with descriptions
  main.tf              3 resources: MK8s cluster, system node group, ray-compute node group
  outputs.tf           Exports cluster_id and node group IDs

scripts/
  00-auth.sh           Fetches a Nebius IAM token and exports project_id + subnet_id
  10-bootstrap.sh      Pulls kubeconfig, installs KubeRay + Kueue, creates namespace and queues
  99-teardown.sh       Deletes all cloud resources and stops billing

k8s/
  kueue-setup.yaml              ResourceFlavor + ClusterQueue (500 CPU quota) + LocalQueue
  rayjob-montecarlo-smoke.yaml  10 workers, 200 tasks — validates the pipeline cheaply
  rayjob-montecarlo.yaml        100 workers, 2,000 tasks, 2B paths — the benchmark run

app/
  price_option.py      Monte Carlo simulation (scale controlled via env vars)
  Dockerfile           Optional: bake the script into an image; default path uses a ConfigMap
```

---

## Prerequisites

- OpenTofu >= 1.8 → https://opentofu.org/docs/intro/install/
- Nebius CLI installed and authenticated (`nebius profile create`)
- `jq`, `kubectl` >= 1.31, `helm` >= 3.14
- Nebius project with ~430 vCPU quota (full run; smoke test needs ~40 vCPU)

---

## Workflow

### 1. Clone and authenticate

```bash
git clone https://github.com/mesutoezdil/Distributed-Computing-with-Ray-on-K8s.git
cd Distributed-Computing-with-Ray-on-K8s
source scripts/00-auth.sh
# Output should show project_id and subnet_id populated
```

### 2. Provision the cluster

```bash
cd tofu
tofu init      # downloads the Nebius provider from the registry
tofu plan      # previews what will be created, no cost yet
tofu apply     # creates cluster + 2 system nodes (~5-10 min)
cd ..
```

**What gets created:** 1 MK8s cluster (K8s 1.31, public endpoint), 2× cpu-d3/8vcpu-32gb system nodes, 1 autoscaling ray-compute node group (starts at 0 nodes, scales up when a job arrives).

**Cost:** System nodes bill hourly while running. Ray workers cost nothing when no job is active (0 nodes).

### 3. Install Kubernetes tooling

```bash
./scripts/10-bootstrap.sh
# - fetches kubeconfig via `nebius mk8s v1 cluster get-credentials`
# - installs KubeRay 1.6.0 via Helm
# - installs Kueue v0.17.0 via kubectl apply
# - creates the quant-team namespace
# - applies Kueue queue objects (500 CPU quota)
# - loads price_option.py as a ConfigMap
```

### 4. Smoke test (cheap, 10 workers)

```bash
kubectl apply -f k8s/rayjob-montecarlo-smoke.yaml
kubectl -n quant-team get rayjob montecarlo-smoke -w
kubectl -n quant-team logs -l job-name=montecarlo-smoke --tail=5
# Expected: price ~6.04, 200M paths, ~15-20 s
```

### 5. Full run (100 workers, 2B paths)

```bash
kubectl apply -f k8s/rayjob-montecarlo.yaml
kubectl -n quant-team get workloads -w                            # watch Kueue admission
kubectl -n quant-team get rayjob montecarlo-pricing -w
kubectl -n quant-team logs -l job-name=montecarlo-pricing --tail=5
# Expected: price ~6.04, 2,000,000,000 paths, 400 CPUs
```

### 6. Tear everything down

```bash
./scripts/99-teardown.sh
```

---

## Cost summary

| State | Active resources | Duration |
|-------|-----------------|----------|
| Cluster up, no job | 2 system nodes | Ongoing |
| Smoke test | +4 ray nodes | ~15-20 min |
| Full run | +~34 ray nodes | ~30-40 min |
| After `tofu destroy` | Nothing | — |

---

## Reproducing the book numbers

Set `ray_autoscaling_enabled = false` and `ray_max_nodes = 34` to pre-provision nodes so that node provisioning latency does not skew wall time. Record alongside your results: provider, region, platform/preset, node count, and Ray/KubeRay/Kueue versions.
