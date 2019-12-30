# Smoke Test

이 챕터에서는 클러스터가 정상적으로 동작하는지 확인하기 위한 일련의 테스트를 진행합니다.

## Data Encryption

이 섹션에서는 데이터를 암호화 하는 기능을 확인합니다.

일반적인 Secret을 작성합니다.

```bash
kubectl create secret generic kubernetes-the-hard-way \
  --from-literal="mykey=mydata"
```

etcd에 저장된 Secret의 hexdump를 출력합니다

```bash
TERRAFORM_OUTPUT=$(terraform12 output --json)
ssh -i ssh/ssh.pem ubuntu@$(echo $TERRAFORM_OUTPUT | jq -r ".controller_public_ips.value[0]") \
    "sudo ETCDCTL_API=3 etcdctl get \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/etcd/ca.pem \
    --cert=/etc/etcd/kubernetes.pem \
    --key=/etc/etcd/kubernetes-key.pem\
    /registry/secrets/default/kubernetes-the-hard-way | hexdump -C"
```

결과:

```
00000000  2f 72 65 67 69 73 74 72  79 2f 73 65 63 72 65 74  |/registry/secret|
00000010  73 2f 64 65 66 61 75 6c  74 2f 6b 75 62 65 72 6e  |s/default/kubern|
00000020  65 74 65 73 2d 74 68 65  2d 68 61 72 64 2d 77 61  |etes-the-hard-wa|
00000030  79 0a 6b 38 73 3a 65 6e  63 3a 61 65 73 63 62 63  |y.k8s:enc:aescbc|
00000040  3a 76 31 3a 6b 65 79 31  3a fd a5 e3 c2 8e 70 8e  |:v1:key1:.....p.|
00000050  0f 24 d5 9c 79 5e 3f 48  d2 37 f5 2c 50 07 d3 b5  |.$..y^?H.7.,P...|
00000060  7d 96 8b 8f 25 71 1c c1  3c 42 6e c9 f5 f4 8d 3b  |}...%q..<Bn....;|
00000070  78 c0 1f d0 c2 6d e1 18  9f 2b 43 7e f0 12 de 80  |x....m...+C~....|
00000080  0c 2e de 1f e1 73 12 0c  d6 0e 53 6d 94 e2 11 4d  |.....s....Sm...M|
00000090  f2 9b ef 0e c4 0c 6a 56  6c 1b 22 55 13 00 3d e9  |......jVl."U..=.|
000000a0  cf 12 b0 57 82 2f 08 a7  fe d2 41 21 fe d7 5f dc  |...W./....A!.._.|
000000b0  48 8e 10 77 48 bd 7f 1e  b5 62 48 33 75 be 49 57  |H..wH....bH3u.IW|
000000c0  41 c7 74 dd 7f a5 0e 16  b0 ae 87 5a 11 6a ab f2  |A.t........Z.j..|
000000d0  e8 87 33 5e b4 2b 26 94  fd c3 14 a7 84 62 57 c1  |..3^.+&......bW.|
000000e0  4d 36 2b 5e c6 2a 81 1f  28 0a                    |M6+^.*..(.|
```

## Deployments

이 섹션에서는 Deployment를 만들고 관리하는 기능을 확인합니다.

nginx 웹 서버에 대한 배치를 작성합니다.

```
kubectl create deployment nginx --image=nginx
```

생성된 nginx Pod을 확인합니다.

```
kubectl get pods -l app=nginx
```

결과:

```
NAME                     READY   STATUS    RESTARTS   AGE
nginx-554b9c67f9-rgw9t   1/1     Running   0          12s
```

### Port Forwarding

이 섹션에서는 포트 포워딩을 사용하여 원격으로 응용 프로그램에 액세스하는 기능을 확인합니다.

로컬 머신의 8080 포트를 nginx Pod의 80 포트에 포워딩 합니다.

```
POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $POD_NAME 8080:80
```

결과:

```
Forwarding from 127.0.0.1:8080 -> 80
Forwarding from [::1]:8080 -> 80
```

새로운 터미널에서 로컬 머신의 8080포트에 http 요청을 보냅니다

```
curl --head http://127.0.0.1:8080
```

결과:

```
HTTP/1.1 200 OK
Server: nginx/1.17.6
Date: Mon, 30 Dec 2019 07:58:56 GMT
Content-Type: text/html
Content-Length: 612
Last-Modified: Tue, 19 Nov 2019 12:50:08 GMT
Connection: keep-alive
ETag: "5dd3e500-264"
Accept-Ranges: bytes
```

기존 터미널에 찍힌 로그도 확인합니다

```
Forwarding from 127.0.0.1:8080 -> 80
Forwarding from [::1]:8080 -> 80
Handling connection for 8080
```

### Logs

이 섹션에서는 컨테이너 로그를 검색하는 기능을 확인합니다.

nginx 팟 로그를 출력합니다.

```
POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath="{.items[0].metadata.name}")
kubectl logs $POD_NAME
```

결과:

```
127.0.0.1 - - [30/Dec/2019:07:58:56 +0000] "HEAD / HTTP/1.1" 200 0 "-" "curl/7.65.1" "-"
```

### Exec

이 섹션에서는 컨테이너에서 명령을 실행하는 기능을 확인합니다.

컨테이너 에서 `nginx -v`명령 을 실행하여 nginx 버전을 인쇄하십시오.

```
POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath="{.items[0].metadata.name}")
kubectl exec -ti $POD_NAME -- nginx -v
```

결과:

```
nginx version: nginx/1.17.6
```

## Services

이 섹션에서는 서비스를 사용하여 응용 프로그램을 노출하는 기능을 확인합니다.

NodePort 서비스를 통해 nginx Deployment를 노출합니다.

```
kubectl expose deployment nginx --port 80 --type NodePort
```

nginx 서비스에 지정된 노드 포트를 검색합니다.

```bash
NODE_PORT=$(kubectl get svc nginx --output=jsonpath='{range .spec.ports[0]}{.nodePort}')
echo $NODE_PORT
```

nginx 노드 포트에 대한 원격 엑세스를 허용하도록 Security Group Rule을 추가합니다.

```terraform
locals {
  nginx_port = XXXXX
}

resource "aws_security_group_rule" "nginx" {
    type = "ingress"
    from_port = local.nginx_port
    to_port = local.nginx_port
    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.external.id
}
```

작업자 노드의 External IP 주소와 nginx노드 포트를 사용하여 HTTP 요청을 보냅니다.

```bash
TERRAFORM_OUTPUT=$(terraform12 output --json)
INSTANCE_IP=$(echo $TERRAFORM_OUTPUT | jq -r ".worker_public_ips.value[0]")
NODE_PORT=$(kubectl get svc nginx --output=jsonpath='{range .spec.ports[0]}{.nodePort}')
curl -I http://$INSTANCE_IP:$NODE_PORT
```

결과:

```
HTTP/1.1 200 OK
Server: nginx/1.17.6
Date: Mon, 30 Dec 2019 08:12:28 GMT
Content-Type: text/html
Content-Length: 612
Last-Modified: Tue, 19 Nov 2019 12:50:08 GMT
Connection: keep-alive
ETag: "5dd3e500-264"
Accept-Ranges: bytes
```
