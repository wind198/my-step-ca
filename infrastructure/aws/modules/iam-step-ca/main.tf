variable "name_prefix" { type = string }
variable "assume_role_policy" {
  type        = string
  description = "JSON trust policy. Local: account root. Prod: IRSA OIDC."
}
variable "tags" {
  type    = map(string)
  default = {}
}

resource "aws_iam_role" "step_ca" {
  name               = "${var.name_prefix}-step-ca"
  assume_role_policy = var.assume_role_policy
  tags               = merge(var.tags, { Purpose = "step-ca" })
}

output "role_arn" { value = aws_iam_role.step_ca.arn }
output "role_name" { value = aws_iam_role.step_ca.name }
