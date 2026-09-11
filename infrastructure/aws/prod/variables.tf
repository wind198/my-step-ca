variable "aws_region" {
  type        = string
  description = "AWS region for KMS and IAM"
}

variable "name_prefix" {
  type        = string
  description = "Resource name prefix (non-secret)"
}

variable "tags" {
  type = map(string)
  default = {
    Project     = "company-pki"
    Environment = "prod"
  }
}

variable "admin_principal_arns" {
  type        = list(string)
  description = "IAM principal ARNs allowed to assume pki-admin (SSO roles / break-glass). Use REPLACE_ME placeholders until known."
  default     = ["arn:aws:iam::AWS_ACCOUNT_ID:role/REPLACE_ME-sso-pki-admins"]
}

variable "oidc_provider_arn" {
  type        = string
  description = "EKS OIDC provider ARN for IRSA"
  default     = "arn:aws:iam::AWS_ACCOUNT_ID:oidc-provider/REPLACE_ME_OIDC"
}

variable "oidc_provider_url" {
  type        = string
  description = "EKS OIDC issuer URL without https:// (IRSA condition)"
  default     = "oidc.eks.REPLACE_ME_REGION.amazonaws.com/id/REPLACE_ME"
}

variable "step_ca_namespace" {
  type    = string
  default = "step-ca"
}

variable "step_ca_service_account" {
  type    = string
  default = "step-ca"
}
