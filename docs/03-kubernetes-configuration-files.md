# Generating Kubernetes Configuration Files for Authentication

## Client Authentication Configs

이 섹션에서는 `controller manager`, `kubelet`, `kube-proxy`, 및 `scheduler`클라이언트와 `admin` 사용자에 대한 kubeconfig 파일을 생성합니다.

### The kubelet Kubernetes Configuration File

Kubelets에 대한 kubeconfig 파일을 생성 할 때 Kubelet의 노드 이름과 일치하는 클라이언트 인증서를 사용해야합니다. 이를 통해 Kuberlet이 Kubernetes Node Authorizer에 의해 올바르게 승인됩니다.

각 작업자 노드에 대한 kubeconfig 파일을 생성합니다.

```bash
mkdir config
TERRAFORM_OUTPUT=$(terraform12 output --json)
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
