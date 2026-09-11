variable "name_prefix" { type = string }
variable "assume_role_policy" {
  type        = string
  description = "JSON trust policy. Local: account root. Prod: SSO/break-glass principals."
}
variable "tags" {
  type    = map(string)
  default = {}
}

resource "aws_iam_role" "admin" {
  name               = "${var.name_prefix}-pki-admin"
  assume_role_policy = var.assume_role_policy
  tags               = merge(var.tags, { Purpose = "pki-admin" })
}

output "role_arn" { value = aws_iam_role.admin.arn }
output "role_name" { value = aws_iam_role.admin.name }
