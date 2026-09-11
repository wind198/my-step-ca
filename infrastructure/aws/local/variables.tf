variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_endpoint" {
  type    = string
  default = "http://localhost:4566"
}

variable "name_prefix" {
  type    = string
  default = "example-pki"
}

variable "tags" {
  type = map(string)
  default = {
    Project     = "company-pki"
    Environment = "local"
    Example     = "true"
  }
}
