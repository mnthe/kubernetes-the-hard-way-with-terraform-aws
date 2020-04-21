# Create CA Cert
echo "Create CA Cert"
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

# Create `admin` client cert
echo "Create `admin` client cert"
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


# Create controller manager client cert
echo "Create controller manager client cert"
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

# Create kube-scheduler cert
echo "Create kube-scheduler cert"
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

# Get terraform data
echo "Get terraform data"
TERRAFORM_OUTPUT=$(terraform output --json)

# Create kube-api-server cert
echo "Create kube-api-server cert"
KUBERNETES_PUBLIC_ADDRESS=$(echo $TERRAFORM_OUTPUT | jq -r '.controller_loadbalancer_public_ip.value')
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

HOSTNAME=10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,$KUBERNETES_PUBLIC_ADDRESS,127.0.0.1,$KUBERNETES_HOSTNAMES
cfssl gencert \
  -ca=ca/ca.pem \
  -ca-key=ca/ca-key.pem \
  -config=ca/ca-config.json \
  -hostname=$HOSTNAME \
  -profile=kubernetes \
  ca/kubernetes-csr.json | cfssljson -bare ca/kubernetes

# Create service-account cert
echo "Create service-account cert"
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

# Create Kubelet client cert
echo "Create Kubelet client cert"
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

# Create kubeproxy cert
echo "Create kubeproxy cert"
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

echo "Copy certs to kubernetes nodes"

TERRAFORM_OUTPUT=$(terraform output --json)
for i in $(seq 0 2); do
    PUBLIC_IP=$(echo $TERRAFORM_OUTPUT | jq -r ".worker_public_ips.value[$i]")
    scp -o StrictHostKeyChecking=no -i ssh/ssh.pem \
        ca/ca.pem ca/worker-$i-key.pem ca/worker-$i.pem ubuntu@$PUBLIC_IP:~/
done

TERRAFORM_OUTPUT=$(terraform output --json)
for i in $(seq 0 2); do
    PUBLIC_IP=$(echo $TERRAFORM_OUTPUT | jq -r ".controller_public_ips.value[$i]")
    scp -o StrictHostKeyChecking=no -i ssh/ssh.pem \
        ca/ca.pem ca/ca-key.pem ca/kubernetes-key.pem ca/kubernetes.pem \
        ca/service-account-key.pem ca/service-account.pem ubuntu@$PUBLIC_IP:~/
done