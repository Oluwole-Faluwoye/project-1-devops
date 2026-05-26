###### THIS IS WHERE YOU OVERRIDE DEFAULT VALUES SAFELY #####################

region      = "us-east-1"
enable_eks  = true

key_name    = "us-east-1-key"

vpc_name    = "devops-vpc"
vpc_cidr    = "10.0.0.0/16"

azs = ["us-east-1a", "us-east-1b"]

public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]