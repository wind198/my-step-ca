data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  admin_trust = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = var.admin_principal_arns }
      Action    = "sts:AssumeRole"
    }]
  })

  # IRSA trust for step-ca ServiceAccount
  step_ca_trust = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:${var.step_ca_namespace}:${var.step_ca_service_account}"
        }
      }
    }]
  })
}

module "admin_role" {
  source             = "../modules/iam-admin"
  name_prefix        = var.name_prefix
  assume_role_policy = local.admin_trust
  tags               = var.tags
}

module "step_ca_role" {
  source             = "../modules/iam-step-ca"
  name_prefix        = var.name_prefix
  assume_role_policy = local.step_ca_trust
  tags               = var.tags
}

module "root_kms" {
  source         = "../modules/kms-root"
  name_prefix    = var.name_prefix
  admin_role_arn = module.admin_role.role_arn
  tags           = var.tags
}

module "intermediate_kms" {
  source           = "../modules/kms-intermediate"
  name_prefix      = var.name_prefix
  admin_role_arn   = module.admin_role.role_arn
  step_ca_role_arn = module.step_ca_role.role_arn
  tags             = var.tags
}

resource "aws_iam_role_policy" "admin_kms" {
  name = "${var.name_prefix}-admin-kms"
  role = module.admin_role.role_name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RootAndIntermediateKMSAdmin"
        Effect = "Allow"
        Action = [
          "kms:CreateKey",
          "kms:DescribeKey",
          "kms:GetPublicKey",
          "kms:Sign",
          "kms:CreateAlias",
          "kms:ListAliases",
          "kms:ScheduleKeyDeletion",
          "kms:TagResource"
        ]
        Resource = [module.root_kms.key_arn, module.intermediate_kms.key_arn]
      }
    ]
  })
}

resource "aws_iam_role_policy" "step_ca_kms" {
  name = "${var.name_prefix}-step-ca-kms"
  role = module.step_ca_role.role_name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "IntermediateSignOnly"
        Effect = "Allow"
        Action = [
          "kms:Sign",
          "kms:GetPublicKey",
          "kms:DescribeKey"
        ]
        Resource = [module.intermediate_kms.key_arn]
      }
    ]
  })
}
