# **Generating the Data Encryption Config and Key**

Kubernetes는 클러스터 상태, 응용 프로그램 설정 및 비밀을 포함한 다양한 데이터를 저장합니다. Kubernetes는 유휴 클러스터 데이터를 암호화 하는 기능을 지원합니다.

이 챕터에서는 Kubernetes Secrets 암호화에 적합한 암호화 키와 암호화 구성 을 생성합니다.

## **The Encryption Key**

암호화 키를 생성합니다.

```bash
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
```

## **The Encryption Config File**

Create the encryption-config.yaml encryption config file:

```bash
cat > config/encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
```

encryption-config.yaml암호화 설정 파일을 각 컨트롤러 인스턴스에 복사합니다.

```bash
TERRAFORM_OUTPUT=$(terraform output --json)
for i in $(seq 0 2); do
    PUBLIC_IP=$(echo $TERRAFORM_OUTPUT | jq -r ".controller_public_ips.value[$i]")
    scp -o StrictHostKeyChecking=no -i ssh/ssh.pem config/encryption-config.yaml ubuntu@$PUBLIC_IP:~/
done
```
