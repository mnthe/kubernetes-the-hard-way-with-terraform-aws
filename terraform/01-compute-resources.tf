resource "aws_vpc" "vpc" {
  cidr_block = "10.240.0.0/16"

  tags = {
    Name = "k8s-the-hard-way-${local.name}-vpc"
  }
}

resource "aws_subnet" "public" {
    vpc_id = aws_vpc.vpc
    cidr_block = "10.240.0.0/24"

    map_public_ip_on_launch = true

    tags = {
        Name = "k8s-the-hard-way-${local.name}-subnet-public"
    }
}

resource "aws_internet_gateway" "gateway" {
    vpc_id = aws_vpc.vpc

    tags = {
        Name = "k8s-the-hard-way-${local.name}-internet-gateway"
    }
}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.vpc
}

resource "aws_route" "public_internet_gateway" {
    route_table_id = aws_route_table.public.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
}