# Kubernetes the hard way with Terraform on AWS

[kelseyhightower/kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way) 를 AWS 위에 Terraform으로 올려봅니다.

## Target Audience

1차 목표는 사내 세미나, 그 이후 다듬기

## Cluster Details

---

- [kubernetes](https://github.com/kubernetes/kubernetes) 1.15.3
- [containerd](https://github.com/containerd/containerd) 1.2.9
- [coredns](https://github.com/coredns/coredns) v1.6.3
- [cni](https://github.com/containernetworking/cni) v0.7.1
- [etcd](https://github.com/coreos/etcd) v3.4.0

## Labs

- [Prerequisites](docs/00-prerequisites.md)
- [Provisioning Computing Resources](docs/01-compute-resources.md)

## TODOS

1. POD_CIDR를 가져오는 부분을 user-data로 변경
2. worker-0, worker-1, worker-2를 인스턴스 아이디를 그대로 사용하도록 변경 또는 커스텀 VPC DNS를 사용하도록 변경
3. Computing Instance를 Autoscaling Group으로 변경
