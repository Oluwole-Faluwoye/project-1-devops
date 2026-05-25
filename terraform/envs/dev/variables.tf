variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "enable_eks" {
  description = "Toggle EKS creation"
  type        = bool
  default     = false
}

variable "key_name" {
  description = "EC2 Key Pair name"
  type        = string
}

variable "vpc_name" {
  description = "VPC name"
  type        = string
  default     = "devops-vpc"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability Zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnets" {
  type = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  type = list(string)
  default = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "jenkins_repo_name" {
  default = "jenkins"
}

variable "app_repo_name" {
  default = "my-app-repo"
}