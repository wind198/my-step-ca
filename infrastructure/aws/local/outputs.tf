output "root_ca_kms_key_arn" {
  value = module.root_kms.key_arn
}

output "root_ca_kms_key_id" {
  value = module.root_kms.key_id
}

output "intermediate_ca_kms_key_arn" {
  value = module.intermediate_kms.key_arn
}

output "intermediate_ca_kms_key_id" {
  value = module.intermediate_kms.key_id
}

output "pki_admin_role_arn" {
  value = module.admin_role.role_arn
}

output "step_ca_role_arn" {
  value = module.step_ca_role.role_arn
}

output "aws_account_id" {
  value = local.account_id
}
