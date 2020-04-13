# Generating Kubernetes Configuration Files for Authentication

## **Client Authentication Configs**

이 섹션에서는 `controller manager`, `kubelet`, `kube-proxy`, 및 `scheduler`클라이언트와 `admin` 사용자에 대한 kubeconfig 파일을 생성합니다.

### **The kubelet Kubernetes Configuration File**

Kubelets에 대한 kubeconfig 파일을 생성 할 때 Kubelet의 노드 이름과 일치하는 클라이언트 인증서를 사용해야합니다. 이를 통해 Kubelet이 Kubernetes Node Authorizer에 의해 올바르게 승인됩니다.

각 작업자 노드에 대한 kubeconfig 파일을 생성합니다.

```bash
mkdir config
TERRAFORM_OUTPUT=$(terraform output --json)
KUBERNETES_PUBLIC_ADDRESS=$(echo $TERRAFORM_OUTPUT | jq -r '.controller_loadbalancer_public_ip.value')
for i in $(seq 0 2); do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca/ca.pem \
    --embed-certs=true \
    --server=https://$KUBERNETES_PUBLIC_ADDRESS:6443 \
    --kubeconfig=config/worker-$i.kubeconfig

  kubectl config set-credentials system:node:worker-$i \
    --client-certificate=ca/worker-$i.pem \
    --client-key=ca/worker-$i-key.pem \
    --embed-certs=true \
    --kubeconfig=config/worker-$i.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:worker-$i \
    --kubeconfig=config/worker-$i.kubeconfig

  kubectl config use-context default --kubeconfig=config/worker-$i.kubeconfig
done
```

다음 파일들이 생성됩니다.

```
kubernetes-key.pem
kubernetes.pem
```

### **The kube-proxy Kubernetes Configuration File**

`kube-proxy` 서비스에 대한 kubeconfig 파일을 생성합니다.

```bash
TERRAFORM_OUTPUT=$(terraform output --json)
KUBERNETES_PUBLIC_ADDRESS=$(echo $TERRAFORM_OUTPUT | jq -r '.controller_loadbalancer_public_ip.value')
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca/ca.pem \
  --embed-certs=true \
  --server=https://$KUBERNETES_PUBLIC_ADDRESS:6443 \
  --kubeconfig=config/kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
  --client-certificate=ca/kube-proxy.pem \
  --client-key=ca/kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=config/kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-proxy \
  --kubeconfig=config/kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=config/kube-proxy.kubeconfig
```

다음 파일이 생성됩니다.

```
kube-proxy.kubeconfig

```

### **The kube-controller-manager Kubernetes Configuration File**

`kube-controller-manager` 서비스에 대한 kubeconfig 파일을 생성합니다.

```bash
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=config/kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=ca/kube-controller-manager.pem \
  --client-key=ca/kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=config/kube-controller-manager.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-controller-manager \
  --kubeconfig=config/kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=config/kube-controller-manager.kubeconfig
```

다음 파일이 생성됩니다.

```
kube-controller-manager.kubeconfig
```

### **The kube-scheduler Kubernetes Configuration File**

kube-scheduler서비스에 대한 kubeconfig 파일을 생성합니다.

```bash
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=config/kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
  --client-certificate=ca/kube-scheduler.pem \
  --client-key=ca/kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=config/kube-scheduler.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-scheduler \
  --kubeconfig=config/kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=config/kube-scheduler.kubeconfig
```

다음 파일이 생성됩니다.

```
kube-scheduler.kubeconfig
```

### **The admin Kubernetes Configuration File**

admin사용자에 대한 kubeconfig 파일을 생성합니다.

```
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=config/admin.kubeconfig

kubectl config set-credentials admin \
  --client-certificate=ca/admin.pem \
  --client-key=ca/admin-key.pem \
  --embed-certs=true \
  --kubeconfig=config/admin.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=admin \
  --kubeconfig=config/admin.kubeconfig

kubectl config use-context default --kubeconfig=config/admin.kubeconfig
```

다음 파일이 생성됩니다.

```
admin.kubeconfig
```

## **Kubernets Config 파일 배포**

`kubelet` 및 `kube-proxy` kubeconfig 파일을 각 작업자 노드에 복사합니다.

```bash
TERRAFORM_OUTPUT=$(terraform output --json)
for i in $(seq 0 2); do
    PUBLIC_IP=$(echo $TERRAFORM_OUTPUT | jq -r ".worker_public_ips.value[$i]")
    scp -o StrictHostKeyChecking=no -i ssh/ssh.pem \
        config/worker-$i.kubeconfig config/kube-proxy.kubeconfig ubuntu@$PUBLIC_IP:~/
done
```

`kube-controller-manager`및 `kube-schedulerkubeconfig` 파일을 각 컨트롤러 노드에 복사합니다.

```bash
TERRAFORM_OUTPUT=$(terraform output --json)
for i in $(seq 0 2); do
    PUBLIC_IP=$(echo $TERRAFORM_OUTPUT | jq -r ".controller_public_ips.value[$i]")
    scp -o StrictHostKeyChecking=no -i ssh/ssh.pem \
        config/admin.kubeconfig config/kube-controller-manager.kubeconfig \
        config/kube-scheduler.kubeconfig ubuntu@$PUBLIC_IP:~/
done
```
