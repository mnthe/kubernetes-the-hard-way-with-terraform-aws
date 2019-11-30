locals {
  region        = "<REGION>"
  name          = "<NAME>"
  backup_bucket = "<BACKUP_BUCKET>"
}

terraform {
  required_version = "> 0.12.0"

  # PUBG S3 Terraform Backend
  backend "s3" {
    bucket = <BUCKET_NAME> # Variables not allowed in terraform block
    key    = "seminar/k8s-the-hard-way/<NAME>"
    region = "ap-northeast-2"
  }
}

provider "aws" {
  region = local.region
}

