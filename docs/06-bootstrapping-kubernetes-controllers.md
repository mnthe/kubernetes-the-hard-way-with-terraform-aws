# **Bootstrapping the Kubernetes Control Plane**

이 챕터에서는 Kubernetes 컨트롤 플레인을 부트 스트랩합니다. 고 가용성을 위해 3개의 컨트롤러 노드에 세팅을 하며, Kubernetes API 서버를 원격 클라이언트에 노출시키는 외부로드 밸런서를 생성합니다.

Kubernetes API 서버, 스케줄러 및 컨트롤러 관리자와 같은 설정 요소가 각 노드에 설치됩니다.

### **Prerequisites**

이 챕터는 컨트롤러 노드 controller-0, controller-1, controller-2 각각에서 실행해야 합니다.

ssh를 통해 컨트롤러 노드에 로그인 합니다.

```bash
TERRAFORM_OUTPUT=$(terraform output --json)
# controller-0
ssh -i ssh/ssh.pem ubuntu@$(echo $TERRAFORM_OUTPUT | jq -r ".controller_public_ips.value[0]")
# controller-1
ssh -i ssh/ssh.pem ubuntu@$(echo $TERRAFORM_OUTPUT | jq -r ".controller_public_ips.value[1]")
# controller-2
ssh -i ssh/ssh.pem ubuntu@$(echo $TERRAFORM_OUTPUT | jq -r ".controller_public_ips.value[2]")
```

## **Provision the Kubernetes Control Plane**

Kubernetes Configuratio 폴더를 생성합니다.

```bash
sudo mkdir -p /etc/kubernetes/config
```

### **Download and Install the Kubernetes Controller Binaries**

공식 Kubernetes 릴리스 바이너리를 다운로드합니다.

```bash
wget -q --show-progress --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-apiserver" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-controller-manager" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-scheduler" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl"
```

Kubernetes 바이너리를 설치합니다

```bash
chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/
```

### **Configure the Kubernetes API Server**

```
sudo mkdir -p /var/lib/kubernetes/
sudo mv ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem \
    encryption-config.yaml /var/lib/kubernetes/
```

노드 내부 IP 주소는 클라이언트 요청을 처리하고 etcd 클러스터 피어와 통신하는 데 사용됩니다. 현재 노드의 Private IP 주소를 검색합니다.

```bash
INTERNAL_IP=$(curl -s http://169.254.169.254/1.0/meta-data/local-ipv4)
```

`kube-apiserver.service` systemd unit file을 작성합니다

```bash
cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=https://10.240.0.10:2379,https://10.240.0.11:2379,https://10.240.0.12:2379 \\
  --event-ttl=1h \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### **Configure the Kubernetes Controller Manager**

`kube-controller-manager.kubeconfig` 파일을 `/var/lib/kubernetes`로 옮깁니다.

```bash
sudo mv kube-controller-manager.kubeconfig /var/lib/kubernetes/
```

`kube-controller-manager.service` systemd unit file을 작성합니다

```bash
cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### **Configure the Kubernetes Scheduler**

`kube-scheduler.kubeconfig` 파일을 `/var/lib/kubernetes`로 옮깁니다.

```bash
sudo mv kube-scheduler.kubeconfig /var/lib/kubernetes/
```

`kube-scheduler.yaml` 설정 파일을 작성합니다.

```bash
cat <<EOF | sudo tee /etc/kubernetes/config/kube-scheduler.yaml
apiVersion: kubescheduler.config.k8s.io/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF
```

`kube-controller-manager.service` systemd unit file을 작성합니다

```bash
cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### **Start the Controller Services**

```bash
sudo systemctl daemon-reload
sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler
```

> Kubernetes API 서버가 완전히 초기화 될 때까지 최대 10 초가 소요됩니다.

### **Enable HTTP Health Checks**

HTTP Status Check를 위해 기본 웹 서버를 설치합니다.

> 각 컨트롤러 노드의 로컬에 nginx를 설치하고 /healthz 엔드포인트를 프록시하여 상태를 체크합니다.

```bash
sudo apt-get update
sudo apt-get install -y nginx
```

```bash
cat > kubernetes.default.svc.cluster.local <<EOF
server {
  listen      80;
  server_name kubernetes.default.svc.cluster.local;

  location /healthz {
     proxy_pass                    https://127.0.0.1:6443/healthz;
     proxy_ssl_trusted_certificate /var/lib/kubernetes/ca.pem;
  }
}
EOF

sudo mv kubernetes.default.svc.cluster.local \
    /etc/nginx/sites-available/kubernetes.default.svc.cluster.local
sudo ln -s /etc/nginx/sites-available/kubernetes.default.svc.cluster.local /etc/nginx/sites-enabled/

sudo systemctl restart nginx
sudo systemctl enable nginx
```

### **Verification**

상태 확인

```
kubectl get componentstatuses --kubeconfig admin.kubeconfig
```

```
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-0               Healthy   {"health":"true"}
etcd-1               Healthy   {"health":"true"}
etcd-2               Healthy   {"health":"true"}
```

nginx HTTP Status Check

```
curl -H "Host: kubernetes.default.svc.cluster.local" -i http://127.0.0.1/healthz
```

```
HTTP/1.1 200 OK
Server: nginx/1.14.0 (Ubuntu)
Date: Sun, 29 Dec 2019 07:40:12 GMT
Content-Type: text/plain; charset=utf-8
Content-Length: 2
Connection: keep-alive
X-Content-Type-Options: nosniff
```

## **RBAC for Kubelet Authorization**

이 섹션에서는 Kubernetes API 서버가 각 작업자 노드의 Kubelet API에 액세스 할 수 있도록 RBAC 권한을 설정합니다. 포드에서 메트릭, 로그 및 명령을 검색하려면 Kubelet API에 액세스해야합니다.

> 이 튜토리얼은 Kubelet의 `--authorization-mode` 플래그를 `Webhook`으로 설정합니다. 웹훅 모드는 [SubjectAccessReview API](https://kubernetes.io/docs/admin/authorization/#checking-api-access)를 사용하여 권한을 결정합니다.

**이 섹션의 명령은 전체 클러스터에 영향을 미치며 컨트롤러 노드 중 하나에서 한 번만 실행하면됩니다.**

```bash
TERRAFORM_OUTPUT=$(terraform output --json)
# controller-0
ssh -i ssh/ssh.pem ubuntu@$(echo $TERRAFORM_OUTPUT | jq -r ".controller_public_ips.value[0]")
```

Kubelet API에 액세스 할 수있는 권한으로 `system:kube-apiserver-to-kubelet` ClusterRole을 생성합니다. 이렇게 만들어진 Role을 통해 팟 관리와 관련된 가장 일반적인 작업을 수행합니다.

```bash
cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF
```

Kubernetes API 서버는 `--kubelet-client-certificate` 플래그로 정의 된 클라이언트 인증서를 사용하여 `kubernetes` 유저로서 Kubelet에 인증합니다.

위에서 생성한 `system:kube-apiserver-to-kubelet` ClusterRole을 `kubernetes`에 바인딩합니다.

```bash
cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF
```

## **The Kubernetes Frontend Load Balancer**

### **Provision a Network Load Balancer**

이 섹션에서는 Kubernetes API 서버를 위해 외부로드 밸런서를 프로비저닝합니다.

Network Load Balancer를 생성한 뒤 챕터 1에서 미리 발급받은 eip를 할당합니다.

```terraform
resource "aws_lb" "public" {
    name = "k8s-the-hard-way-${local.name}-lb"
    load_balancer_type = "network"

    subnet_mapping {
        subnet_id = aws_subnet.public.id
        allocation_id = aws_eip.public.id
    }
}

resource "aws_lb_target_group" "controllers" {
    name     = "k8s-the-hard-way-${local.name}-tg"
    port     = 6443
    protocol = "TCP"
    vpc_id   = aws_vpc.vpc.id
}

resource "aws_lb_target_group_attachment" "controller_attachment" {
    count            = 3
    target_group_arn = aws_lb_target_group.controllers.arn
    target_id        = aws_instance.controller[count.index].id
    port             = 6443
}

resource "aws_lb_listener" "controllers" {
    load_balancer_arn = aws_lb.public.arn
    port              = "6443"
    protocol          = "TCP"

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.controllers.arn
    }
}

output "controller_loadbalancer_public_ip" {
    value = aws_eip.public.public_ip
}
```

### **Verification**

```bash
TERRAFORM_OUTPUT=$(terraform output --json)
KUBERNETES_PUBLIC_ADDRESS=$(echo $TERRAFORM_OUTPUT | jq -r '.controller_loadbalancer_public_ip.value')
curl --cacert ca/ca.pem https://$KUBERNETES_PUBLIC_ADDRESS:6443/version
```

결과

```json
{
  "major": "1",
  "minor": "15",
  "gitVersion": "v1.15.3",
  "gitCommit": "2d3c76f9091b6bec110a5e63777c332469e0cba2",
  "gitTreeState": "clean",
  "buildDate": "2019-08-19T11:05:50Z",
  "goVersion": "go1.12.9",
  "compiler": "gc",
  "platform": "linux/amd64"
}
```
