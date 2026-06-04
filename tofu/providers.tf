# Authentication: the provider reads credentials from the environment.
# scripts/00-auth.sh exports an IAM token from your Nebius CLI profile
# (or use a service account per the Nebius provider quickstart).
provider "nebius" {
  # No static credentials in code. Ever.
}
