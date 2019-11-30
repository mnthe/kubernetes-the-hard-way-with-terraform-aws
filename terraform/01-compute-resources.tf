# 1. Create VPC
resource "aws_vpc" "vpc" {
  cidr_block = "10.240.0.0/16"

  tags = {
    Name = "k8s-the-hard-way-${local.name}-vpc"
  }
}

# 2. Create Subnet
resource "aws_subnet" "public" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = "10.240.0.0/24"

    map_public_ip_on_launch = true

    tags = {
        Name = "k8s-the-hard-way-${local.name}-subnet-public"
    }
}

resource "aws_internet_gateway" "gateway" {
    vpc_id = aws_vpc.vpc.id

    tags = {
        Name = "k8s-the-hard-way-${local.name}-internet-gateway"
    }
}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.vpc.id
}

resource "aws_route" "public_internet_gateway" {
    route_table_id = aws_route_table.public.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
}

# 3. Create Security Groups
resource "aws_security_group" "internal" {
    name = "k8s-the-hard-way-${local.name}-sg-internal"
    vpc_id = aws_vpc.vpc.id

    ingress {
        from_port = 0
        to_port = 0
        protocol = "tcp"
        cidr_blocks = ["10.240.0.0/16"]
    }

    ingress {
        from_port = 0
        to_port = 0
        protocol = "udp"
        cidr_blocks = ["10.240.0.0/16"]
    }

    ingress {
        from_port = 0
        to_port = 0
        protocol = "icmp"
        cidr_blocks = ["10.240.0.0/16"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "external" {
    name = "k8s-the-hard-way-${local.name}-sg-external"
    vpc_id = aws_vpc.vpc.id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 6443
        to_port = 6443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 0
        to_port = 0
        protocol = "icmp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}


