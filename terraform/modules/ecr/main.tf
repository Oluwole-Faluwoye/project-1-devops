variable "name" {}

resource "aws_ecr_repository" "repo" {

  name         = var.name

  force_delete = true

  # lifecycle {

  #  prevent_destroy = true
  # }

  image_scanning_configuration {

    scan_on_push = true
  }
}