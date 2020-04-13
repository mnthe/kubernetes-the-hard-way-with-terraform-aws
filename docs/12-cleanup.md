# Cleaning Up

실습에서 사용된 리소스들을 정리합니다.

## Terraform destroy

`terraform destroy` 명령을 통해 전체 리소스를 제거합니다.

> Plan: 0 to add, 0 to change, 33 to destroy.

```
terraform destroy
```

## Remove files

실습에서 생성한 파일을 삭제합니다.

```
rm -rf ./*
```

## Remove Kubeconfig

로컬 kubeconfig에 등록된 kubeconfig를 삭제합니다.

```
kubectl config unset current-context

kubectl config delete-context kubernetes-the-hard-way
kubectl config delete-cluster kubernetes-the-hard-way
kubectl config unset users.admin

kubectl config use-context $(kubectl config get-contexts -o name | head -n 1)
```
