provider "aws" {
  region = var.aws_region
  # Credentials: SSO / env / shared config — never hard-code.
  # No LocalStack endpoints.
}
