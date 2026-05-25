variable "name" {}
variable "cidr" {}
variable "azs" {}
variable "public_subnets" {}
variable "private_subnets" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.name
  cidr = var.cidr

  azs = var.azs

  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_nat_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true
}