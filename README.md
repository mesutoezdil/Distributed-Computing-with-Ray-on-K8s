# Distributed Computing with Ray on K8s

Infrastructure-as-code and manifests for the Monte Carlo lab in *Cloud Native HPC and AI Infrastructure*, Chapter 6 (Distributed Computing with Ray on Kubernetes).

This repo spins up a Nebius Managed Kubernetes (MK8s) cluster with OpenTofu, bootstraps KubeRay 1.6.0 and Kueue 0.17, and runs a 100-worker (400 CPU) Ray Monte Carlo simulation through a Kueue queue. Tested versions: Ray 2.55.1, KubeRay 1.6.0, Kueue 0.17.0, Kubernetes 1.31+, OpenTofu 1.8+.

Everything in the stack is open source: OpenTofu is MPL-2.0 licensed and a CNCF project, and Ray, KubeRay, and Kueue are Apache-2.0. The Kubernetes manifests in `k8s/` are vendor neutral; only `tofu/` is Nebius specific. Swap that directory for your provider's module and everything else runs unchanged.

## Repository layout

```
tofu/         MK8s cluster + 2 node groups (system fixed, ray-compute autoscaled 0..N)
scripts/      auth, bootstrap (kubeconfig, KubeRay, Kueue, namespaces), teardown
k8s/          Kueue queue objects, smoke RayJob (10 workers), full RayJob (100 workers)
app/          price_option.py simulation + Dockerfile (optional; default path uses a ConfigMap)
```

## Prerequisites

- OpenTofu >= 1.8 (https://opentofu.org/docs/intro/install/)
- Nebius CLI installed and authenticated (`nebius profile create ...`), plus `jq`
- `kubectl` >= 1.31, Helm >= 3.14
- A Nebius project with quota for the chosen CPU preset (~430 vCPUs at peak for the full run)

## Workflow

```bash
# 1. Authenticate and export Nebius IDs (project, subnet) as input variables
source scripts/00-auth.sh

# 2. Provision the cluster and node groups (~5-10 min)
cd tofu
tofu init
tofu plan
tofu apply
cd ..

# 3. Fetch kubeconfig, install KubeRay + Kueue, create namespaces and queues
./scripts/10-bootstrap.sh

# 4. Smoke test: 10 workers, 200 tasks (validates the whole pipeline cheaply)
kubectl apply -f k8s/rayjob-montecarlo-smoke.yaml
kubectl -n quant-team get rayjob montecarlo-smoke -w

# 5. Full run: 100 workers, 2,000 tasks, 2B paths
kubectl apply -f k8s/rayjob-montecarlo.yaml
kubectl -n quant-team get workloads -w        # watch Kueue admission
kubectl -n quant-team get rayjob montecarlo-pricing -w
kubectl -n quant-team logs -l job-name=montecarlo-pricing --tail=5

# 6. Tear everything down (stops all billing)
./scripts/99-teardown.sh
```

Expected result of the full run: an estimated option price near the Black-Scholes closed-form value of ~6.04 for the hardcoded parameters, printed with total paths and wall time.

## Cost control

- The `ray-compute` node group autoscales from 0. With no job running, you pay for 2 small system nodes only; the MK8s control plane is free.
- `max_node_count` caps the burst at the infrastructure layer; the Kueue `ClusterQueue` quota caps it at the workload layer. Both are set in this repo.
- `tofu destroy` removes everything. Run it the same day as your benchmark.

## Notes for reproducing book numbers

For the measurement that goes into the chapter, prefer `fixed_node_count` over autoscaling (set `ray_autoscaling_enabled = false` in `tofu.tfvars`) so node provisioning latency doesn't pollute the wall time, and record: provider, region, platform/preset, node count, Ray/KubeRay/Kueue versions, and the full job log.
