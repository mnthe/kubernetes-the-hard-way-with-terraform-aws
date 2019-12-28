# Provisioning a CA and Generating TLS Certificates

cfssl을 사용하여 PKI 인프라를 프로비저닝하고, `etcd`, `kube-apiserver`, `kube-controller-manager`, `kube-scheduler`, `kubelet`, `kube-proxy`에 대한 TLS 인증서를 생성합니다.

## Certificate Authority

CA 구성파일을 저장하고, 인증서 및 Private Key를 생성합니다.

```bash
mkdir ca
cat > ca/ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca/ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert -initca ca/ca-csr.json | cfssljson -bare ca/ca
```

다음 파일들이 생성됩니다.

```
ca-key.pem
ca.pem
```

## Client and Server Certificates

이 섹션에서는 각 Kubernetes 구성 요소에 대한 클라이언트 및 서버 인증서와 Kubernetes `admin` 사용자에 대한 클라이언트 인증서를 생성합니다.

### The Admin Client Certificate

`admin` 클라이언트 인증서와 private key를 생성합니다.

```bash
cat > ca/admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca/ca.pem \
  -ca-key=ca/ca-key.pem \
  -config=ca/ca-config.json \
  -profile=kubernetes \
  ca/admin-csr.json | cfssljson -bare ca/admin
```

다음 파일들이 생성됩니다.

```
admin-key.pem
admin.pem
```

### The Kubelet Client Certificates

Kubernetes는 Node Authorizer라는 특수 목적의 권한 부여 모드를 사용합니다. 이 모드 는 Kubelets의 API 요청을 구체적으로 승인합니다. 노드 인증 자에 의해 권한을 부여 받기 위해 Kubelets는 `system:node:<nodeName>` 사용자 이름이 `system:nodes` 그룹 에있는 것으로 식별하는 자격 증명을 사용해야합니다.

각 Kubernetes 작업자 노드의 kubelet 클라이언트 인증서 및 Private Key를 생성합니다.

```bash
TERRAFORM_OUTPUT=$(terraform output --json)

for i in $(seq 0 2); do
cat > ca/worker-$i-csr.json <<EOF
{
  "CN": "system:node:worker-$i",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

PUBLIC_IP=$(echo $TERRAFORM_OUTPUT | jq -r ".worker_public_ips.value[$i]")
PRIVATE_IP=$(echo $TERRAFORM_OUTPUT | jq -r ".worker_private_ips.value[$i]")

cfssl gencert \
  -ca=ca/ca.pem \
  -ca-key=ca/ca-key.pem \
  -config=ca/ca-config.json \
  -hostname=worker-$i,$PUBLIC_IP,$PRIVATE_IP \
  -profile=kubernetes \
  ca/worker-$i-csr.json | cfssljson -bare ca/worker-$i
done
```

다음 파일들이 생성됩니다.

```
worker-0-key.pem
worker-0.pem
worker-1-key.pem
worker-1.pem
worker-2-key.pem
worker-2.pem
```

### The Controller Manager Client Certificate

`kube-controller-manager` 클라이언트 인증서 및 Private Key를 생성합니다.

```bash
cat > ca/kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca/ca.pem \
  -ca-key=ca/ca-key.pem \
  -config=ca/ca-config.json \
  -profile=kubernetes \
  ca/kube-controller-manager-csr.json | cfssljson -bare ca/kube-controller-manager
```

다음 파일들이 생성됩니다.

```
kube-controller-manager-key.pem
kube-controller-manager.pem
```

### The Kube Proxy Client Certificate

`kube-proxy`의 클라이언트 인증서 및 Private Key를 생성합니다.

```bash
cat > ca/kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca/ca.pem \
  -ca-key=ca/ca-key.pem \
  -config=ca/ca-config.json \
  -profile=kubernetes \
  ca/kube-proxy-csr.json | cfssljson -bare ca/kube-proxy
```

다음 파일들이 생성됩니다.

```
kube-proxy-key.pem
kube-proxy.pem
```

### The Scheduler Client Certificate

`kube-scheduler`의 클라이언트 인증서 및 Private Key를 생성합니다.

```bash
cat > ca/kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca/ca.pem \
  -ca-key=ca/ca-key.pem \
  -config=ca/ca-config.json \
  -profile=kubernetes \
  ca/kube-scheduler-csr.json | cfssljson -bare ca/kube-scheduler
```

다음 파일들이 생성됩니다.

```
kube-scheduler-key.pem
kube-scheduler.pem
```

### The Kubernetes API Server Certificate

`kubernetes-api-server`의 클라이언트 인증서 및 Private Key를 생성합니다.

`kubernetes-api-server`의 인증서에는 Kubernetes에서 사용하는 정적 IP 주소가 주체 대체 이름 목록에 포함됩니다.

```bash

TERRAFORM_OUTPUT=$(terraform output --json)

KUBERNETES_PUBLIC_IPS=$(echo $TERRAFORM_OUTPUT | jq -r '.worker_public_ips.value | join(",")')
KUBERNETES_PRIVATE_IPS=$(echo $TERRAFORM_OUTPUT | jq -r '.worker_private_ips.value | join(",")')
KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

cat > ca/kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

HOSTNAME=10.32.0.1,$KUBERNETES_PRIVATE_IPS,$KUBERNETES_PUBLIC_IPS,127.0.0.1,$KUBERNETES_HOSTNAMES
cfssl gencert \
  -ca=ca/ca.pem \
  -ca-key=ca/ca-key.pem \
  -config=ca/ca-config.json \
  -hostname=$HOSTNAME \
  -profile=kubernetes \
  ca/kubernetes-csr.json | cfssljson -bare ca/kubernetes
```

다음 파일들이 생성됩니다.

```
kubernetes-key.pem
kubernetes.pem
```

## The Service Account Key Pair

Kubernetes Controller Manager는 서비스 계정 관리 문서에 설명 된대로 키 쌍을 사용하여 서비스 계정 토큰을 생성하고 서명합니다 .

`service-account` 인증서 및 Public Key를 생성합니다.

```bash
cat > ca/service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca/ca.pem \
  -ca-key=ca/ca-key.pem \
  -config=ca/ca-config.json \
  -profile=kubernetes \
  ca/service-account-csr.json | cfssljson -bare ca/service-account
```

다음 파일들이 생성됩니다.

```
service-account-key.pem
service-account.pem
```

## Distribute the Client and Server Certificates

적절한 인증서와 개인 키를 각 Worker 인스턴스에 복사합니다.

```bash
TERRAFORM_OUTPUT=$(terraform output --json)
for i in $(seq 0 2); do
    PUBLIC_IP=$(echo $TERRAFORM_OUTPUT | jq -r ".worker_public_ips.value[$i]")
    scp -o StrictHostKeyChecking=no -i ssh/ssh.pem ca/ca.pem ca/worker-$i-key.pem ca/worker-$i.pem ubuntu@$PUBLIC_IP:~/
done
```

적절한 인증서 및 개인 키를 각 Controller 인스턴스에 복사하십시오.

```bash
TERRAFORM_OUTPUT=$(terraform output --json)
for i in $(seq 0 2); do
    PUBLIC_IP=$(echo $TERRAFORM_OUTPUT | jq -r ".controller_public_ips.value[$i]")
    scp -o StrictHostKeyChecking=no -i ssh/ssh.pem \
    ca/ca.pem ca/ca-key.pem ca/kubernetes-key.pem ca/kubernetes.pem \
    ca/service-account-key.pem ca/service-account.pem ubuntu@$PUBLIC_IP:~/
done
```

> `kube-proxy`, `kube-controller-manager`, `kube-scheduler`, `kubelet` 클라이언트 인증서는 다음 챕터에서 클라이언트 인증 구성 파일을 생성하는데 사용됨
