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

resource "aws_route_table_association" "route_table_association" {
    subnet_id      = aws_subnet.public.id
    route_table_id = aws_route_table.public.id
}

resource "aws_main_route_table_association" "main_route_table_association" {
  vpc_id         = aws_vpc.vpc.id
  route_table_id = aws_route_table.public.id
}


# 3. Create Security Groups
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

resource "aws_security_group" "internal" {
    name = "k8s-the-hard-way-${local.name}-sg-internal"
    vpc_id = aws_vpc.vpc.id

    ingress {
        from_port = 0
        to_port = 65535
        protocol = "tcp"
        cidr_blocks = ["10.240.0.0/16"]
    }

    ingress {
        from_port = 0
        to_port = 65535
        protocol = "tcp"
        self = true
    }

    ingress {
        from_port = 0
        to_port = 65535
        protocol = "udp"
        cidr_blocks = ["10.240.0.0/16"]
    }

    ingress {
        from_port = 0
        to_port = 65535
        protocol = "udp"
        self = true
    }

    ingress {
        from_port = -1
        to_port = -1
        protocol = "icmp"
        cidr_blocks = ["10.240.0.0/16"]
    }

    ingress {
        from_port = -1
        to_port = -1
        protocol = "icmp"
        self = true
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# 4. Create Computing Instances // TODO: Autoscaling Group으로 변경

resource "aws_key_pair" "ssh" {
    key_name = "k8s-the-hard-way-${local.name}-ssh-key"
    public_key = file("./ssh/ssh.pem.pub")
}

data "aws_ami" "ubuntu" {
    most_recent = true
    name_regex  = "^ubuntu/images/hvm-ssd/ubuntu-bionic-18.04.*"
    owners = ["099720109477"] // Owned by Canonical

    filter {
        name = "architecture"
        values = ["x86_64"]
    }

    filter {
        name   = "root-device-type"
        values = ["ebs"]
    }

    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }
}

resource "aws_instance" "controller" {
    count = 3

    ami = data.aws_ami.ubuntu.id
    instance_type = "t3.medium"

    subnet_id = aws_subnet.public.id
    private_ip = "10.240.0.1${count.index}"

    vpc_security_group_ids = [
        aws_security_group.external.id,
        aws_security_group.internal.id
    ]

    key_name = "k8s-the-hard-way-${local.name}-ssh-key"

    root_block_device {
        volume_type = "gp2"
        volume_size = 200
    }

    tags = {
        "Name" = "k8s-the-hard-way-${local.name}-controller-${count.index}"
        "Type" = "controller"
    }
}

resource "aws_instance" "worker" {
    count = 3

    ami = data.aws_ami.ubuntu.id
    instance_type = "t3.large"

    subnet_id = aws_subnet.public.id
    private_ip = "10.240.0.2${count.index}"

    vpc_security_group_ids = [
        aws_security_group.external.id,
        aws_security_group.internal.id
    ]

    key_name = "k8s-the-hard-way-${local.name}-ssh-key"

    root_block_device {
        volume_type = "gp2"
        volume_size = 200
    }

    tags = {
        "Name" = "k8s-the-hard-way-${local.name}-worker-${count.index}"
        "pod-cidr" = "10.200.0.0/24"
        "Type" = "worker"
    }
}

output "controller_public_ips" {
    value = aws_instance.controller.*.public_ip
}

output "controller_private_ips" {
    value = aws_instance.controller.*.private_ip
}

output "worker_public_ips" {
    value = aws_instance.worker.*.public_ip
}

output "worker_private_ips" {
    value = aws_instance.worker.*.private_ip
}


# 5. Create Loadbalancer for Controller (Kubernetes API Server)

resource "aws_eip" "public" {
    vpc = true

    tags = {
        Name = "k8s-the-hard-way-${local.name}-lb-eip"
    }
}

resource "aws_lb" "public" {
    name = "k8s-the-hard-way-${local.name}-lb"
    load_balancer_type = "network"

    subnet_mapping {
        subnet_id = aws_subnet.public.id
        allocation_id = aws_eip.public.id
    }
}

resource "aws_lb_target_group" "controllers" {
    name     = "k8s-the-hard-way-${local.name}-tg"
    port     = 6443
    protocol = "TCP"
    vpc_id   = aws_vpc.vpc.id
}

resource "aws_lb_target_group_attachment" "controller_attachment" {
    count            = 3
    target_group_arn = aws_lb_target_group.controllers.arn
    target_id        = aws_instance.controller[count.index].id
    port             = 6443
}

resource "aws_lb_listener" "controllers" {
    load_balancer_arn = aws_lb.public.arn
    port              = "6443"
    protocol          = "TCP"

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.controllers.arn
    }
}

output "controller_loadbalancer_public_ip" {
    value = aws_eip.public.public_ip
}
