variable "name_prefix" { type = string }
variable "admin_role_arn" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "root" {
  description              = "${var.name_prefix} Root CA signing key"
  deletion_window_in_days  = 7
  enable_key_rotation      = false
  key_usage                = "SIGN_VERIFY"
  customer_master_key_spec = "RSA_3072"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootAccountAdmin"
        Effect    = "Allow"
        Principal = { AWS = "*" }
        Action    = "kms:*"
        Resource  = "*"
        Condition = {
          StringEquals = {
            "kms:CallerAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid       = "AllowPKIAdmin"
        Effect    = "Allow"
        Principal = { AWS = var.admin_role_arn }
        Action = [
          "kms:DescribeKey",
          "kms:GetPublicKey",
          "kms:Sign",
          "kms:CreateAlias"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, { Purpose = "root-ca" })
}

resource "aws_kms_alias" "root" {
  name          = "alias/${var.name_prefix}-root-ca"
  target_key_id = aws_kms_key.root.key_id
}

output "key_arn" { value = aws_kms_key.root.arn }
output "key_id" { value = aws_kms_key.root.key_id }
