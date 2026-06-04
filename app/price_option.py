"""European call option pricing via distributed Monte Carlo on Ray.

Each task simulates PATHS_PER_TASK terminal prices under geometric Brownian
motion and returns only its batch mean payoff; the driver discounts the
average of the batch means into the option price. Scale is configurable via
environment variables so the same script powers the 10-worker smoke run and
the 100-worker full run.
"""

import os
import time

import numpy as np
import ray

ray.init()

# Option and market parameters: spot, strike, maturity (years),
# risk-free rate, volatility. Black-Scholes closed form for these is ~6.04.
S0, K, T, r, sigma = 100.0, 110.0, 1.0, 0.05, 0.2

PATHS_PER_TASK = int(os.environ.get("PATHS_PER_TASK", "1000000"))
NUM_TASKS = int(os.environ.get("NUM_TASKS", "2000"))


@ray.remote(num_cpus=1)
def simulate_batch(seed: int) -> float:
    """Simulate PATHS_PER_TASK terminal prices, return the batch mean payoff."""
    rng = np.random.default_rng(seed)
    z = rng.standard_normal(PATHS_PER_TASK)
    st = S0 * np.exp((r - 0.5 * sigma**2) * T + sigma * np.sqrt(T) * z)
    payoff = np.maximum(st - K, 0.0)
    return float(payoff.mean())


def main() -> None:
    start = time.perf_counter()

    # Launch all tasks at once; Ray queues what doesn't fit yet.
    refs = [simulate_batch.remote(seed) for seed in range(NUM_TASKS)]

    # Consume results in batches of 100 as they complete so finished
    # ObjectRefs are released early instead of held until the slowest task.
    means = []
    while refs:
        done, refs = ray.wait(refs, num_returns=min(100, len(refs)))
        means.extend(ray.get(done))

    # Discount the average payoff back to today to get the option price.
    price = float(np.exp(-r * T) * np.mean(means))
    elapsed = time.perf_counter() - start

    print(f"Estimated option price: {price:.4f}")
    print(f"Paths simulated: {PATHS_PER_TASK * NUM_TASKS:,}")
    print(f"Wall time: {elapsed:.1f}s on {int(ray.cluster_resources()['CPU'])} CPUs")


if __name__ == "__main__":
    main()
