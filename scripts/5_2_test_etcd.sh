TERRAFORM_OUTPUT=$(terraform output --json)
# controller-0
ssh -i ssh/ssh.pem ubuntu@$(echo $TERRAFORM_OUTPUT | jq -r ".controller_public_ips.value[0]") 'bash -s' < ./locals/5_2_test_etcd.sh
# controller-1
ssh -i ssh/ssh.pem ubuntu@$(echo $TERRAFORM_OUTPUT | jq -r ".controller_public_ips.value[1]") 'bash -s' < ./locals/5_2_test_etcd.sh
# controller-2
ssh -i ssh/ssh.pem ubuntu@$(echo $TERRAFORM_OUTPUT | jq -r ".controller_public_ips.value[2]") 'bash -s' < ./locals/5_2_test_etcd.sh