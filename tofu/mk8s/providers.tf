provider "nebius" {
  # No static credentials. IAM token read from NEBIUS_IAM_TOKEN env var.
  # eu-west1 project (project-e01shg0apr00wftx32nr8y) tells the global API
  # which region to deploy into — no domain override needed.
}
