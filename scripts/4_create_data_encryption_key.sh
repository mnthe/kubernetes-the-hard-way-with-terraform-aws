# Create Encryption Key
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

# Create Encryption configfile
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

# Deploy encryption key to config node
TERRAFORM_OUTPUT=$(terraform output --json)
for i in $(seq 0 2); do
    PUBLIC_IP=$(echo $TERRAFORM_OUTPUT | jq -r ".controller_public_ips.value[$i]")
    scp -o StrictHostKeyChecking=no -i ssh/ssh.pem config/encryption-config.yaml ubuntu@$PUBLIC_IP:~/
done