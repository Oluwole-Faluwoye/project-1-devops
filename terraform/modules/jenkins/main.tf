variable "subnet_id" {}

variable "key_name" {}

variable "user_data_path" {}

variable "vpc_id" {}

# =========================================================
# SECURITY GROUP
# =========================================================

resource "aws_security_group" "jenkins_sg" {

  name = "jenkins-sg"

  vpc_id = var.vpc_id

  # -----------------------------------------------------
  # SSH
  # -----------------------------------------------------

  ingress {

    from_port = 22

    to_port = 22

    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  # -----------------------------------------------------
  # Jenkins
  # -----------------------------------------------------

  ingress {

    from_port = 8080

    to_port = 8080

    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  # -----------------------------------------------------
  # SonarQube
  # -----------------------------------------------------

  ingress {

    from_port = 9000

    to_port = 9000

    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  # -----------------------------------------------------
  # Outbound Access
  # -----------------------------------------------------

  egress {

    from_port = 0

    to_port = 0

    protocol = "-1"

    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {

    Name = "jenkins-sg"
  }
}

# =========================================================
# IAM ROLE
# =========================================================

resource "aws_iam_role" "jenkins_role" {

  name = "jenkins-ec2-role"

  assume_role_policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {

        Action = "sts:AssumeRole"

        Effect = "Allow"

        Principal = {

          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# =========================================================
# CUSTOM INLINE POLICY
# =========================================================

resource "aws_iam_role_policy" "jenkins_inline_policy" {

  name = "jenkins-devops-policy"

  role = aws_iam_role.jenkins_role.id

  policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      # ==================================================
      # ECR ACCESS
      # ==================================================

      {

        Effect = "Allow"

        Action = [

          "ecr:GetAuthorizationToken",

          "ecr:BatchCheckLayerAvailability",

          "ecr:GetDownloadUrlForLayer",

          "ecr:GetRepositoryPolicy",

          "ecr:DescribeRepositories",

          "ecr:ListImages",

          "ecr:DescribeImages",

          "ecr:BatchGetImage",

          "ecr:InitiateLayerUpload",

          "ecr:UploadLayerPart",

          "ecr:CompleteLayerUpload",

          "ecr:PutImage"
        ]

        Resource = "*"
      },

      # ==================================================
      # EKS ACCESS
      # ==================================================

      {

        Effect = "Allow"

        Action = [

          "eks:DescribeCluster",

          "eks:DescribeNodegroup",

          "eks:ListClusters",

          "eks:ListNodegroups",

          "eks:AccessKubernetesApi"
        ]

        Resource = "*"
      },

      # ==================================================
      # EC2 DESCRIBE ACCESS
      # ==================================================

      {

        Effect = "Allow"

        Action = [

          "ec2:DescribeInstances",

          "ec2:DescribeSubnets",

          "ec2:DescribeSecurityGroups",

          "ec2:DescribeRouteTables",

          "ec2:DescribeVpcs",

          "ec2:DescribeVolumes",

          "ec2:DescribeAvailabilityZones"
        ]

        Resource = "*"
      },

      # ==================================================
      # IAM PASS ROLE
      # ==================================================

      {

        Effect = "Allow"

        Action = [

          "iam:PassRole"
        ]

        Resource = "*"
      },

      # ==================================================
      # CLOUDWATCH LOGS
      # ==================================================

      {

        Effect = "Allow"

        Action = [

          "logs:*"
        ]

        Resource = "*"
      }
    ]
  })
}

# =========================================================
# OPTIONAL ADMIN ACCESS (LAB/LEARNING)
# =========================================================

resource "aws_iam_role_policy_attachment" "admin" {

  role = aws_iam_role.jenkins_role.name

  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# =========================================================
# INSTANCE PROFILE
# =========================================================

resource "aws_iam_instance_profile" "jenkins_profile" {

  role = aws_iam_role.jenkins_role.name
}

# =========================================================
# EC2 INSTANCE
# =========================================================

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

  # -----------------------------------------------------
  # ROOT VOLUME
  # -----------------------------------------------------

  root_block_device {

    volume_size = 30

    volume_type = "gp3"

    delete_on_termination = true
  }

  tags = {

    Name = "Jenkins-Server"
  }
}

# =========================================================
# DEDICATED PERSISTENT EBS VOLUME
# =========================================================

resource "aws_ebs_volume" "jenkins_data" {

  availability_zone = aws_instance.jenkins.availability_zone

  size = 30

  type = "gp3"

  encrypted = true

#  lifecycle {

#    prevent_destroy = true
#  }

  tags = {

    Name = "jenkins-data-volume"
  }
}

# =========================================================
# ATTACH EBS TO EC2
# =========================================================

resource "aws_volume_attachment" "jenkins_attach" {

  device_name = "/dev/xvdf"

  volume_id = aws_ebs_volume.jenkins_data.id

  instance_id = aws_instance.jenkins.id

  force_detach = true
}