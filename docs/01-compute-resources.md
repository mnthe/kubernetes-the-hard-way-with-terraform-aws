# Provisioning Computing Resource

## **Networking**

클러스터를 위한 네트워크를 생성합니다. Kubernetes [네트워킹 모델](https://kubernetes.io/docs/concepts/cluster-administration/networking/#kubernetes-model)은 컨테이너와 노드가 서로 통신할 수 있는 플랫 네트워크를 가정합니다.

### 1. Create Virtual Private Cloud(VPC) Network

실습을 위한 전용 VPC를 생성합니다.

```terraform
resource "aws_vpc" "vpc" {
  cidr_block = "10.240.0.0/16"

  tags = {
    Name = "k8s-the-hard-way-vpc-${local.name}"
  }
}
```

### **2. Create Public Subnet**

Public IP 자동 설정이 켜진 Subnet 하나와 외부로 연결될 수 있도록 Internet Gateway, Route Table을 생성합니다.

이후 새로 만들어진 Route Table을 VPC에 할당합니다.

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

resource "aws_route_table_association" "route_table_association" {
    subnet_id      = aws_subnet.public.id
    route_table_id = aws_route_table.public.id
}

resource "aws_main_route_table_association" "main_route_table_association" {
  vpc_id         = aws_vpc.vpc.id
  route_table_id = aws_route_table.public.id
}
```

### **3. Create Security Groups**

내부 / 외부 통신을 위한 Security group을 각각 1개씩 생성합니다

- 내부: tcp, udp, icmp 허용
- 외부: tcp:22, tcp:6443, icmp 허용

```terraform
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
        from_port = 0
        to_port = 8
        protocol = "icmp"
        cidr_blocks = ["10.240.0.0/16"]
    }

    ingress {
        from_port = 0
        to_port = 8
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

```

## **Computing Resources**

### **1. Create ssh key and upload to aws ec2 key pair**

머신을 위한 ssh키를 생성합니다

```bash
mkdir ./ssh
ssh-keygen -t rsa -f ./ssh/ssh.pem
```

만들어진 ssh키를 aws에 등록합니다.

```terraform
resource "aws_key_pair" "ssh" {
    key_name = "k8s-the-hard-way-${local.name}-ssh-key"
    public_key = file("./ssh/ssh.pem.pub")
}
```

### **2. Create Worker and Controller Instances**

컨트롤러 노드와 작업자 노드를 각각 3개씩 생성합니다.

```terraform
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

resource "aws_iam_role" "controller_role" {
    name = "k8s-the-hard-way-${local.name}-controller-role"

    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "controller_policy" {
    name = "k8s-the-hard-way-${local.name}-controller-policy"
    role = aws_iam_role.controller_role.id

    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
          "ec2:DescribeTags"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "controller_profile" {
  name = "k8s-the-hard-way-${local.name}-controller-profile"
  role = aws_iam_role.controller_role.name
}

resource "aws_iam_role" "worker_role" {
  name = "k8s-the-hard-way-${local.name}-worker-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "worker_policy" {
    name = "k8s-the-hard-way-${local.name}-worker-policy"
    role = aws_iam_role.worker_role.id

    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
          "ec2:DescribeTags"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "worker_profile" {
  name = "k8s-the-hard-way-${local.name}-worker-profile"
  role = aws_iam_role.worker_role.name
}

resource "aws_instance" "controller" {
    count = 3

    ami = data.aws_ami.ubuntu.id
    instance_type = "t3.medium"

    subnet_id = aws_subnet.public.id
    private_ip = "10.240.0.1${count.index}"
    source_dest_check = false

    vpc_security_group_ids = [
        aws_security_group.external.id,
        aws_security_group.internal.id
    ]

    key_name = "k8s-the-hard-way-${local.name}-ssh-key"
    iam_instance_profile = aws_iam_instance_profile.controller_profile.name

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
    source_dest_check = false

    vpc_security_group_ids = [
        aws_security_group.external.id,
        aws_security_group.internal.id
    ]

    key_name = "k8s-the-hard-way-${local.name}-ssh-key"
    iam_instance_profile = aws_iam_instance_profile.worker_profile.name

    root_block_device {
        volume_type = "gp2"
        volume_size = 200
    }

    tags = {
        "Name" = "k8s-the-hard-way-${local.name}-worker-${count.index}"
        "POD_CIDR" = "10.200.${count.index}.0/24"
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
```

### **3. Set Hostmane & Add to /etc/host**

작업자 노드와 컨트롤러 노드의 Hostname을 변경합니다.

추가로 각 노드에 서로의 주소를 /etc/host에 등록하여 hostname으로 서로를 찾을 수 있도록 설정합니다.

```bash
TERRAFORM_OUTPUT=$(terraform output --json)
for i in $(seq 0 2); do
    PUBLIC_IP=$(echo $TERRAFORM_OUTPUT | jq -r ".worker_public_ips.value[$i]")
    ssh -i ssh/ssh.pem ubuntu@$PUBLIC_IP sudo hostnamectl set-hostname worker-$i
    ssh -i ssh/ssh.pem ubuntu@$PUBLIC_IP 'echo "preserve_hostname: true" | sudo tee --append /etc/cloud/cloud.cfg'
    for j in $(seq 0 2); do
        PRIVATE_IP=$(echo $TERRAFORM_OUTPUT | jq -r ".worker_private_ips.value[$j]")
        ssh -i ssh/ssh.pem ubuntu@$PUBLIC_IP "echo \"$PRIVATE_IP worker-$j worker-$j.cluster.local\" | sudo tee --append /etc/hosts"
        PRIVATE_IP=$(echo $TERRAFORM_OUTPUT | jq -r ".controller_private_ips.value[$j]")
        ssh -i ssh/ssh.pem ubuntu@$PUBLIC_IP "echo \"$PRIVATE_IP controller-$j controller-$j.cluster.local\" | sudo tee --append /etc/hosts"
    done
done

for i in $(seq 0 2); do
    PUBLIC_IP=$(echo $TERRAFORM_OUTPUT | jq -r ".controller_public_ips.value[$i]")
    ssh -i ssh/ssh.pem ubuntu@$PUBLIC_IP sudo hostnamectl set-hostname controller-$i
    ssh -i ssh/ssh.pem ubuntu@$PUBLIC_IP 'echo "preserve_hostname: true" | sudo tee --append /etc/cloud/cloud.cfg'
    for j in $(seq 0 2); do
        PRIVATE_IP=$(echo $TERRAFORM_OUTPUT | jq -r ".worker_private_ips.value[$j]")
        ssh -i ssh/ssh.pem ubuntu@$PUBLIC_IP "echo \"$PRIVATE_IP worker-$j worker-$j.cluster.local\" | sudo tee --append /etc/hosts"
        PRIVATE_IP=$(echo $TERRAFORM_OUTPUT | jq -r ".controller_private_ips.value[$j]")
        ssh -i ssh/ssh.pem ubuntu@$PUBLIC_IP "echo \"$PRIVATE_IP controller-$j controller-$j.cluster.local\" | sudo tee --append /etc/hosts"
    done
done
```

### **4. Create Loadbalancer for Kubernetes API Server**

이후 챕터에서 Kubernetes API Server의 고 가용성을 위해 Load Balancer를 사용하게 됩니다.

해당 Load Balancer에서 사용할 EIP를 미리 발급받습니다.

```terraform
resource "aws_eip" "public" {
    vpc = true

    tags = {
        Name = "k8s-the-hard-way-${local.name}-lb-eip"
    }
}

output "controller_loadbalancer_public_ip" {
    value = aws_eip.public.public_ip
}
```
