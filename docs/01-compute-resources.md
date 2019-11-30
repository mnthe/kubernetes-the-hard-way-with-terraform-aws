# Provisioning Computing Resource

## Networking

---

클러스터를 위한 네트워크를 생성합니다. Kubernetes [네트워킹 모델](https://kubernetes.io/docs/concepts/cluster-administration/networking/#kubernetes-model)은 컨테이너와 노드가 서로 통신할 수 있는 플랫 네트워크를 가정합니다.

### **1. Create Virtual Private Cloud(VPC) Network**

실습을 위한 전용 VPC를 생성합니다.

```terraform
resource "aws_vpc" "vpc" {
  cidr_block = "10.240.0.0/16"

  tags = {
    Name = "k8s-the-hard-way-vpc-${local.name}"
  }
}

resource "aws_subnet" "public" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = "10.240.0.0/24"

    map_public_ip_on_launch = true

    tags = {
        Name = "k8s-the-hard-way-subnet-public-${local.name}"
    }
}
```

### 2. Create Public Subnet

Public IP 자동 설정이 켜진 Subnet 하나와 외부로 연결될 수 있도록 Internet Gateway, Route Table을 생성합니다.

```terraform
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
```

### 3. Create Security Groups

내부 / 외부 통신을 위한 Security group을 각각 1개씩 생성합니다

- 내부: tcp, udp, icmp 허용
- 외부: tcp:22, tcp:6443, icmp 허용

```terraform
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
```
