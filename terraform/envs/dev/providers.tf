terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }

  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host = try(module.eks[0].cluster_endpoint, null)

  cluster_ca_certificate = try(
    base64decode(module.eks[0].cluster_certificate_authority_data),
    null
  )

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"

    args = [
      "eks",
      "get-token",
      "--cluster-name",
      try(module.eks[0].cluster_name, ""),
      "--region",
      var.region
    ]
  }
}