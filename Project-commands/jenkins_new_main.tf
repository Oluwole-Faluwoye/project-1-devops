###############################################################
# VARIABLES
###############################################################

variable "subnet_id" {}
variable "key_name" {}
variable "user_data_path" {}
variable "vpc_id" {}

###############################################################
# SECURITY GROUP
###############################################################

resource "aws_security_group" "jenkins_sg" {

  name   = "jenkins-sg"

  vpc_id = var.vpc_id

  ###########################################################
  # SSH
  ###########################################################

  ingress {

    from_port = 22
    to_port   = 22

    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  ###########################################################
  # JENKINS
  ###########################################################

  ingress {

    from_port = 8080
    to_port   = 8080

    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  ###########################################################
  # SONARQUBE
  ###########################################################

  ingress {

    from_port = 9000
    to_port   = 9000

    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  ###########################################################
  # JENKINS AGENTS
  ###########################################################

  ingress {

    from_port = 50000
    to_port   = 50000

    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  ###########################################################
  # OUTBOUND
  ###########################################################

  egress {

    from_port = 0
    to_port   = 0

    protocol = "-1"

    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {

    Name = "jenkins-security-group"
  }
}

###############################################################
# IAM ROLE
###############################################################

resource "aws_iam_role" "jenkins_role" {

  name = "jenkins-ec2-role"

  assume_role_policy = jsonencode({

    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

###############################################################
# IAM POLICY ATTACHMENTS
###############################################################

resource "aws_iam_role_policy_attachment" "ecr" {

  role = aws_iam_role.jenkins_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

resource "aws_iam_role_policy_attachment" "eks" {

  role = aws_iam_role.jenkins_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_worker" {

  role = aws_iam_role.jenkins_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

###############################################################
# INSTANCE PROFILE
###############################################################

resource "aws_iam_instance_profile" "jenkins_profile" {

  role = aws_iam_role.jenkins_role.name
}

###############################################################
# EC2 INSTANCE
###############################################################

resource "aws_instance" "jenkins" {

  ami = "ami-0c02fb55956c7d316"

  instance_type = "t3.medium"

  subnet_id = var.subnet_id

  associate_public_ip_address = true

  key_name = var.key_name

  vpc_security_group_ids = [
    aws_security_group.jenkins_sg.id
  ]

  iam_instance_profile = aws_iam_instance_profile.jenkins_profile.name

  user_data = file(var.user_data_path)

  ###########################################################
  # ROOT VOLUME
  ###########################################################

  root_block_device {

    volume_size = 30

    volume_type = "gp3"

    encrypted = true

    delete_on_termination = true
  }

  tags = {

    Name = "Jenkins-Server"
  }
}

###############################################################
# OUTPUTS
###############################################################

output "jenkins_public_ip" {

  value = aws_instance.jenkins.public_ip
}

output "security_group_id" {

  value = aws_security_group.jenkins_sg.id
}