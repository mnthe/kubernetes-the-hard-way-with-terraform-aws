# Configuring kubectl for Remote Access

이 세션에서는 `admin` 유저를 기반으로 `kubectl`에서 사용하기 위한 자격증명을 생성합니다.

## The Admin Kubernetes Configuration File

각 kubeconfig에는 Kubernetes API 서버가 연결되어 있어야합니다. 고 가용성을 지원하기 위해 Kubernetes API 서버 앞에 있는 외부로드 밸런서에 할당 된 IP 주소가 사용됩니다.

`admin` 사용자 인증에 적합한 kubeconfig 파일을 생성합니다.

> 주의) 로컬의 default kubeconfig에 본 세션의 credential이 추가됩니다.

```bash
TERRAFORM_OUTPUT=$(terraform12 output --json)
KUBERNETES_PUBLIC_ADDRESS=$(echo $TERRAFORM_OUTPUT | jq -r '.controller_loadbalancer_public_ip.value')

kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca/ca.pem \
    --embed-certs=true \
    --server=https://$KUBERNETES_PUBLIC_ADDRESS:6443

kubectl config set-credentials admin \
    --client-certificate=ca/admin.pem \
    --client-key=ca/admin-key.pem

kubectl config set-context kubernetes-the-hard-way \
    --cluster=kubernetes-the-hard-way \
    --user=admin

kubectl config use-context kubernetes-the-hard-way
```

## Verification

원격 Kubernetes 클러스터의 상태를 확인합니다.

```
kubectl get componentstatuses
```

결과:

```
NAME                 STATUS    MESSAGE             ERROR
scheduler            Healthy   ok
controller-manager   Healthy   ok
etcd-2               Healthy   {"health":"true"}
etcd-1               Healthy   {"health":"true"}
etcd-0               Healthy   {"health":"true"}
```

원격 Kubernetes 클러스터의 노드를 나열합니다.

```
kubectl get nodes
```

결과:

```
NAME       STATUS   ROLES    AGE     VERSION
worker-0   Ready    <none>   9m34s   v1.15.3
worker-1   Ready    <none>   9m32s   v1.15.3
worker-2   Ready    <none>   9m29s   v1.15.3
```
