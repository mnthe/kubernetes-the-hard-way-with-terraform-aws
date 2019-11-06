locals {
  region        = "<REGION>"
  name          = "<NAME>"
  backup_bucket = "<BACKUP_BUCKET>"
}

terraform {
  required_version = "> 0.12.0"

  # PUBG S3 Terraform Backend
  backend "s3" {
    bucket = local.backup_bucket
    key    = "seminar/k8s-the-hard-way/${local.name}"
    region = "ap-northeast-2"
  }
}

provider "aws" {
  region = local.region
}

