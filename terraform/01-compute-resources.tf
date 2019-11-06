resource "aws_vpc" "vpc" {
  cidr_block = "10.240.0.0/16"

  tags = {
    Name = "vpc-k8s-the-hard-way-${local.name}"
  }
}
