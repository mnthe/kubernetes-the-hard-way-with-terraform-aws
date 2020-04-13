# Kubernetes the hard way with Terraform on AWS

[kelseyhightower/kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way) 를 AWS 위에 Terraform으로 올려봅니다.

## Target Audience

1차 목표는 사내 세미나, 그 이후 다듬기

## Cluster Details

- [kubernetes](https://github.com/kubernetes/kubernetes) 1.15.3
- [containerd](https://github.com/containerd/containerd) 1.2.9
- [coredns](https://github.com/coredns/coredns) v1.6.3
- [cni](https://github.com/containernetworking/cni) v0.7.1
- [etcd](https://github.com/coreos/etcd) v3.4.0

## Labs

- [0. Prerequisites](docs/00-prerequisites.md)
- [1. Provisioning Computing Resources](docs/01-compute-resources.md)
- [2. Provisioning a CA and Generating TLS Certificates](docs/02-certificate-authority.md)
- [3. Generating Kubernetes Configuration Files for Authentication](docs/03-kubernetes-configuration-files.md)
- [4. Generating the Data Encryption Config and Key](docs/04-data-encryption-keys.md)
- [5. Bootstrapping the ETCD Cluster](docs/05-bootstrapping-etcd.md)
- [6. Bootstrapping the Kubernetes Control Plane](docs/06-bootstrapping-kubernetes-controllers.md)
- [7. Bootstrapping the Kubernetes Worker Nodes](docs/07-bootstrapping-kubernetes-workers.md)
- [8. Configuring kubectl for Remote Access](docs/08-configuring-kubectl.md)
- [9. Provisioning Pod Network Routes](docs/09-pod-network-routes.md)
- [10. Deploying the DNS Cluster Add-on](docs/10-dns-addon.md)
- [11. Smoke Test](docs/11-smoke-test.md)
- [12. Cleaning Up](docs/12-cleanup.md)

## TODOs

1. POD_CIDR를 가져오는 부분을 user-data로 변경
2. worker-0, worker-1, worker-2를 노드 아이디를 그대로 사용하도록 변경 또는 커스텀 VPC DNS를 사용하도록 변경
3. Computing 노드를 Autoscaling Group으로 변경
