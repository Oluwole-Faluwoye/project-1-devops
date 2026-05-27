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

  enable_nat_gateway = true

  single_nat_gateway = true

  one_nat_gateway_per_az = false

  enable_dns_hostnames = true

  enable_dns_support = true

  map_public_ip_on_launch = true

  public_subnet_tags = {

    "kubernetes.io/role/elb" = "1"

    "kubernetes.io/cluster/devops-cluster" = "shared"
  }

  private_subnet_tags = {

    "kubernetes.io/role/internal-elb" = "1"

    "kubernetes.io/cluster/devops-cluster" = "shared"
  }

  tags = {

    Terraform = "true"

    Environment = "dev"
  }
}