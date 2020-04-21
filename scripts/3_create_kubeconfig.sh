mkdir config
TERRAFORM_OUTPUT=$(terraform output --json)
KUBERNETES_PUBLIC_ADDRESS=$(echo $TERRAFORM_OUTPUT | jq -r '.controller_loadbalancer_public_ip.value')

# Create worker node's kube-config
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

# Create kube-proxy kube-config
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

# Create kube-controller-manager kubeconfig
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

# Create kube-scheduler kubeconfig

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

# Create admin user's kubeconfig
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

# Deploy kubelet, kube-proxy kubeconfig to worker nodes
for i in $(seq 0 2); do
    PUBLIC_IP=$(echo $TERRAFORM_OUTPUT | jq -r ".worker_public_ips.value[$i]")
    scp -o StrictHostKeyChecking=no -i ssh/ssh.pem \
        config/worker-$i.kubeconfig config/kube-proxy.kubeconfig ubuntu@$PUBLIC_IP:~/
done

# Deploy kube-controller-manager, kube-scheduler kubeconfig to controller nodes
for i in $(seq 0 2); do
    PUBLIC_IP=$(echo $TERRAFORM_OUTPUT | jq -r ".controller_public_ips.value[$i]")
    scp -o StrictHostKeyChecking=no -i ssh/ssh.pem \
        config/admin.kubeconfig config/kube-controller-manager.kubeconfig \
        config/kube-scheduler.kubeconfig ubuntu@$PUBLIC_IP:~/
done