variable "vpc_id" {}

variable "subnet_ids" {}

variable "jenkins_sg_id" {}

module "eks" {

  source  = "terraform-aws-modules/eks/aws"

  version = "~> 20.0"

  cluster_name = "devops-cluster"

  vpc_id = var.vpc_id

  subnet_ids = var.subnet_ids

  cluster_endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  # =========================================================
  # EKS ACCESS ENTRY FOR JENKINS EC2 ROLE
  # =========================================================

  access_entries = {

    jenkins_admin = {

      principal_arn = "arn:aws:iam::761018849945:role/jenkins-ec2-role"

      policy_associations = {

        admin = {

          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

          access_scope = {

            type = "cluster"
          }
        }
      }
    }
  }

  # =========================================================
  # SECURITY GROUP RULES
  # =========================================================

  cluster_security_group_additional_rules = {

    jenkins_access = {

      protocol = "tcp"

      from_port = 443

      to_port = 443

      type = "ingress"

      source_security_group_id = var.jenkins_sg_id
    }
  }

  # =========================================================
  # MANAGED NODE GROUPS
  # =========================================================

  eks_managed_node_groups = {

    default = {

      desired_size = 1

      max_size = 2

      min_size = 1

      instance_types = ["t3.medium"]

      capacity_type = "ON_DEMAND"
    }
  }

  tags = {

    Environment = "dev"

    Terraform = "true"
  }
}