# Bootstrapping the etcd Cluster

Kubernetes는 상태를 etcd에 저장합니다. 이 챕터에서는 3개의 컨트롤러 노드에 etcd 클러스터를 부트스트래핑 합니다.

## Prerequisites

이 챕터는 컨트롤러 인스턴스 controller-0, controller-1, controller-2 각각에서 실행해야 합니다.

ssh를 통해 컨트롤러 인스턴스에 로그인 합니다.

```bash
TERRAFORM_OUTPUT=$(terraform output --json)
# controller-0
ssh -i ssh/ssh.pem ubuntu@$(echo $TERRAFORM_OUTPUT | jq -r ".controller_public_ips.value[0]")
# controller-1
ssh -i ssh/ssh.pem ubuntu@$(echo $TERRAFORM_OUTPUT | jq -r ".controller_public_ips.value[1]")
# controller-2
ssh -i ssh/ssh.pem ubuntu@$(echo $TERRAFORM_OUTPUT | jq -r ".controller_public_ips.value[2]")
```

## Bootstrapping an etcd Cluster Member

### etcd binary 다운로드 및 설치

etcd GitHub 프로젝트 에서 공식 etcd 릴리스 바이너리를 다운로드합니다.

```bash
wget -q --show-progress --https-only --timestamping \
  "https://github.com/etcd-io/etcd/releases/download/v3.4.0/etcd-v3.4.0-linux-amd64.tar.gz"
```

etcd서버와 etcdctl command line tool을 추출하여 설치합니다.

```bash
tar -xvf etcd-v3.4.0-linux-amd64.tar.gz
sudo mv etcd-v3.4.0-linux-amd64/etcd* /usr/local/bin/
```

### etcd 서버 구성

```bash
sudo mkdir -p /etc/etcd /var/lib/etcd
sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
```

인스턴스 내부 IP 주소는 클라이언트 요청을 처리하고 etcd 클러스터 피어와 통신하는 데 사용됩니다. 현재 인스턴스의 Private IP 주소를 검색합니다.

```bash
INTERNAL_IP=$(curl -s http://169.254.169.254/1.0/meta-data/local-ipv4)
```

각 etcd 멤버는 etcd 클러스터 내에서 고유한 이름을 가져야합니다. etcd 이름을 현재 인스턴스의 호스트 이름과 일치하도록 설정합니다.

```bash
ETCD_NAME=$(hostname -s)
```

`etcd.service` systemd unit file을 작성합니다

```bash
cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster controller-0=https://10.240.0.10:2380,controller-1=https://10.240.0.11:2380,controller-2=https://10.240.0.12:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### etcd 서비스 실행

```
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd
```

## Verification

etcd cluster member를 나열해봅니다.

```bash
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem
```

결과

```bash
3a57933972cb5131, started, controller-2, https://10.240.0.12:2380, https://10.240.0.12:2379
f98dc20bce6225a0, started, controller-0, https://10.240.0.10:2380, https://10.240.0.10:2379
ffed16798470cab5, started, controller-1, https://10.240.0.11:2380, https://10.240.0.11:2379
```
