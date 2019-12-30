# Deploying the DNS Cluster Add-on

이 챕터에서는 Kubernetes 클러스터 내에서 실행되는 응용 프로그램에 DNS 기반 서비스 검색을 제공 하는 `CoreDNS` DNS 애드온을 배포 합니다.

## The DNS Cluster Add-on

`coredns` 클러스터 애드온을 배포합니다.

```
kubectl apply -f https://storage.googleapis.com/kubernetes-the-hard-way/coredns.yaml
```

결과:

```
serviceaccount/coredns created
clusterrole.rbac.authorization.k8s.io/system:coredns created
clusterrolebinding.rbac.authorization.k8s.io/system:coredns created
configmap/coredns created
deployment.apps/coredns created
service/kube-dns created
```

`codedns` 팟이 정상적으로 생성되었는지 확인합니다.

```
kubectl get pods -l k8s-app=kube-dns -n kube-system
```

결과:

```
NAME                     READY   STATUS    RESTARTS   AGE
coredns-5fb99965-4cf9r   1/1     Running   0          65s
coredns-5fb99965-wxrzm   1/1     Running   0          65s
```

## Verification

`busybox`를 배포합니다.

```
    kubectl run --generator=run-pod/v1 busybox --image=busybox:1.28 --command -- sleep 3600
```

`busybox`가 정상적으로 배포되었는지 확인합니다.

```
kubectl get pods -l run=busybox
```

결과:

```
NAME      READY   STATUS    RESTARTS   AGE
busybox   1/1     Running   0          35s

```

`busybox` 팟 내부에서 DNS 조회를 실행합니다.

```bash
POD_NAME=$(kubectl get pods -l run=busybox -o jsonpath="{.items[0].metadata.name}")
kubectl exec -ti $POD_NAME -- nslookup kubernetes
```

결과:

```
Server:    10.32.0.10
Address 1: 10.32.0.10 kube-dns.kube-system.svc.cluster.local

Name:      kubernetes
Address 1: 10.32.0.1 kubernetes.default.svc.cluster.local
```
