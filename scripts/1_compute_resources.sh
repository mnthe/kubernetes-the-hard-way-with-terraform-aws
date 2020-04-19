read -p "Enter your name: " name
read -p "Enter AWS region: " region
read -p "Enter terraform backup bucket: " bucket
read -p "Enter terraform backup bucket region: " bucket_region

cat > 00-prerequisite.tf <<EOF
locals {
  region        = "$region"
  name          = "$name"
}

terraform {
  required_version = "> 0.12.0"

  backend "s3" {
    bucket = "$bucket"
    key    = "seminar/k8s-the-hard-way/$name"
    region = "$bucket_region"
  }
}

provider "aws" {
  region = local.region
}

output "region" {
    value = local.region
}

EOF

mkdir ./ssh
ssh-keygen -t rsa -f ./ssh/ssh.pem -N ""

cp ../terraform/01-compute-resources.tf ./01-compute-resources.tf
terraform init
terraform apply


TERRAFORM_OUTPUT=$(terraform output --json)
for i in $(seq 0 2); do
    PUBLIC_IP=$(echo $TERRAFORM_OUTPUT | jq -r ".worker_public_ips.value[$i]")
    ssh -i ssh/ssh.pem ubuntu@$PUBLIC_IP sudo hostnamectl set-hostname worker-$i
    ssh -i ssh/ssh.pem ubuntu@$PUBLIC_IP 'echo "preserve_hostname: true" | sudo tee --append /etc/cloud/cloud.cfg'
    for j in $(seq 0 2); do
        PRIVATE_IP=$(echo $TERRAFORM_OUTPUT | jq -r ".worker_private_ips.value[$j]")
        ssh -i ssh/ssh.pem ubuntu@$PUBLIC_IP "echo \"$PRIVATE_IP worker-$j worker-$j.cluster.local\" | sudo tee --append /etc/hosts"
        PRIVATE_IP=$(echo $TERRAFORM_OUTPUT | jq -r ".controller_private_ips.value[$j]")
        ssh -i ssh/ssh.pem ubuntu@$PUBLIC_IP "echo \"$PRIVATE_IP controller-$j controller-$j.cluster.local\" | sudo tee --append /etc/hosts"
    done
done

for i in $(seq 0 2); do
    PUBLIC_IP=$(echo $TERRAFORM_OUTPUT | jq -r ".controller_public_ips.value[$i]")
    ssh -i ssh/ssh.pem ubuntu@$PUBLIC_IP sudo hostnamectl set-hostname controller-$i
    ssh -i ssh/ssh.pem ubuntu@$PUBLIC_IP 'echo "preserve_hostname: true" | sudo tee --append /etc/cloud/cloud.cfg'
    for j in $(seq 0 2); do
        PRIVATE_IP=$(echo $TERRAFORM_OUTPUT | jq -r ".worker_private_ips.value[$j]")
        ssh -i ssh/ssh.pem ubuntu@$PUBLIC_IP "echo \"$PRIVATE_IP worker-$j worker-$j.cluster.local\" | sudo tee --append /etc/hosts"
        PRIVATE_IP=$(echo $TERRAFORM_OUTPUT | jq -r ".controller_private_ips.value[$j]")
        ssh -i ssh/ssh.pem ubuntu@$PUBLIC_IP "echo \"$PRIVATE_IP controller-$j controller-$j.cluster.local\" | sudo tee --append /etc/hosts"
    done
done