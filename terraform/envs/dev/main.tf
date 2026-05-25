# VPC
module "vpc" {
  source = "../../modules/vpc"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs = var.azs

  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
}

# ECR - Jenkins Image
module "jenkins_ecr" {
  source = "../../modules/ecr"
  name   = var.jenkins_repo_name
}

# ECR - Application Images
module "app_ecr" {
  source = "../../modules/ecr"
  name   = var.app_repo_name
}

# Jenkins EC2
module "jenkins" {
  source = "../../modules/jenkins"

  subnet_id      = module.vpc.public_subnets[0]
  key_name       = var.key_name
  user_data_path = "${path.module}/setup.sh"
  vpc_id         = module.vpc.vpc_id
}

# EKS (optional - cost controlled)
module "eks" {
  source = "../../modules/eks"

  count = var.enable_eks ? 1 : 0

  vpc_id        = module.vpc.vpc_id
  subnet_ids    = module.vpc.private_subnets
  jenkins_sg_id = module.jenkins.security_group_id
}