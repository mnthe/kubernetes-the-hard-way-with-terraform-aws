# Provisioning Computing Resource

## Networking
----

클러스터를 위한 네트워크를 생성합니다. Kubernetes [네트워킹 모델](https://kubernetes.io/docs/concepts/cluster-administration/networking/#kubernetes-model)은 컨테이너와 노드가 서로 통신할 수 있는 플랫 네트워크를 가정합니다.

### **1. Create Virtual Private Cloud(VPC) Network**

실습을 위한 전용 VPC를 생성합니다.

```terraform
resource "aws_vpc" "vpc" {
  cidr_block = "10.240.0.0/16"

  tags = {
    Name = "vpc-k8s-the-hard-way-${local.name}"
  }
}
```

### 2. Create Subnet and ...