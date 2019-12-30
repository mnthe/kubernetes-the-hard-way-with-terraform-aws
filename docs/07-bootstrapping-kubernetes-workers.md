# Bootstrapping the Kubernetes Worker Nodes

이 챕터에서는 3개의 Kubernetes 워커 인스턴스를 부트스트래핑 합니다. 각 워커 인스턴스에 `runc`, `container networking plugins, containerd`, `kubelet`, `kube-proxy`가 설치됩니다.

### **Prerequisites**

이 챕터는 워커 인스턴스 worker-0, worker-1, worker-2 각각에서 실행해야 합니다.

ssh를 통해 워커 인스턴스에 로그인 합니다.

```bash
TERRAFORM_OUTPUT=$(terraform output --json)
# worker-0
ssh -i ssh/ssh.pem ubuntu@$(echo $TERRAFORM_OUTPUT | jq -r ".worker_public_ips.value[0]")
# worker-1
ssh -i ssh/ssh.pem ubuntu@$(echo $TERRAFORM_OUTPUT | jq -r ".worker_public_ips.value[1]")
# worker-2
ssh -i ssh/ssh.pem ubuntu@$(echo $TERRAFORM_OUTPUT | jq -r ".worker_public_ips.value[2]")
```

## Provisioning a Kubernetes Worker Node

의존성 패키지를 설치합니다

```bash
sudo apt-get update
sudo apt-get -y install socat conntrack ipset
```

### Disable Swap

swap이 활성화 되어있으면 Kubelet이 시작되지 않습니다.

swap이 활성화 되어있는지 확인합니다. 출력되는것이 없으면 swap이 활성화 되어있지 않은 상태입니다.

```
sudo swapon --show
```

swap이 활성화 된 경우 다음 명령을 실행하여 swap을 비활성화 합니다.

```
sudo swapoff -a
```

### Download and Install Worker Binaries

필요한 바이너리를 다운로드합니다.

```
wget -q --show-progress --https-only --timestamping \
  https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.15.0/crictl-v1.15.0-linux-amd64.tar.gz \
  https://github.com/opencontainers/runc/releases/download/v1.0.0-rc8/runc.amd64 \
  https://github.com/containernetworking/plugins/releases/download/v0.8.2/cni-plugins-linux-amd64-v0.8.2.tgz \
  https://github.com/containerd/containerd/releases/download/v1.2.9/containerd-1.2.9.linux-amd64.tar.gz \
  https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl \
  https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubelet
```

설치 디렉토리를 생성합니다

```
sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes
```

다운로드받은 바이너리를 설치합니다.

```
mkdir containerd
tar -xvf crictl-v1.15.0-linux-amd64.tar.gz
tar -xvf containerd-1.2.9.linux-amd64.tar.gz -C containerd
sudo tar -xvf cni-plugins-linux-amd64-v0.8.2.tgz -C /opt/cni/bin/
sudo mv runc.amd64 runc
chmod +x crictl kubectl kube-proxy kubelet runc
sudo mv crictl kubectl kube-proxy kubelet runc /usr/local/bin/
sudo mv containerd/bin/* /bin/
```

### Configure CNI Networking

워커 인스턴스에 aws cli와 jq를 설치합니다.

```
sudo apt install awscli jq -y
```

현재 워커 인스턴스의 태그를 통해 Pod CIDR 범위를 가져옵니다.

> TODO: user-data를 써서 조금 더 쉽게 해보거나 한다.

```bash
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document|grep region|awk -F\" '{print $4}')
POD_CIDR=$(aws ec2 describe-tags --region $REGION --filters "Name=resource-id,Values=$INSTANCE_ID" | jq -r ".Tags[] | select(.Key == \"POD_CIDR\") | .Value")
```

`bridge` 네트워크 설정 파일을 작성합니다.

```bash
cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF
```

`loopback` 네트워크 설정 파일을 작성합니다.

```bash
cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.3.1",
    "name": "lo",
    "type": "loopback"
}
EOF
```

### Configure containerd

`containerd` 설정 파일을 작성합니다.

```
sudo mkdir -p /etc/containerd/
```

```bash
cat << EOF | sudo tee /etc/containerd/config.toml
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
EOF
```

`containerd.service` systemd unit file을 작성합니다

```bash
cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF
```

### Configure the Kubelet

kubelet이 사용하는 인증서와 private key를 적절한 폴더로 옮깁니다.

```bash
sudo mv $HOSTNAME-key.pem $HOSTNAME.pem /var/lib/kubelet/
sudo mv $HOSTNAME.kubeconfig /var/lib/kubelet/kubeconfig
sudo mv ca.pem /var/lib/kubernetes/
```

`kubelet-config.yaml` 설정 파일을 작성합니다.

```bash
cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "${POD_CIDR}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/$HOSTNAME.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/$HOSTNAME-key.pem"
EOF
```

`kubelet.service` systemd unit file을 작성합니다

```bash
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### Configure the Kubernetes Proxy

`kube-proxy.kubeconfig`를 `/var/lib/kube-proxy/kubeconfig`로 옮깁니다.

```
sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
```

`kube-proxy-config.yaml` 설정 파일을 작성합니다.

```bash
cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
EOF
```

`kube-proxy.service` systemd unit file을 작성합니다

```bash
cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### Start the Worker Services

```
sudo systemctl daemon-reload
sudo systemctl enable containerd kubelet kube-proxy
sudo systemctl start containerd kubelet kube-proxy
```

## Verification

등록된 Kubernetes worker node를 나열합니다.

```bash
ssh -i ssh/ssh.pem ubuntu@$(echo $TERRAFORM_OUTPUT | jq -r ".controller_public_ips.value[0]") kubectl get nodes --kubeconfig admin.kubeconfig
```

결과:

```
NAME       STATUS   ROLES    AGE    VERSION
worker-0   Ready    <none>   2m8s   v1.15.3
worker-1   Ready    <none>   2m6s   v1.15.3
worker-2   Ready    <none>   2m3s   v1.15.3
```
