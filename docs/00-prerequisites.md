# Prerequisites

## 1. Install Cli Tools
----

### **1) Terraform**

[다운로드 페이지](https://www.terraform.io/downloads.html)에서 Terraform을 다운로드 받습니다.

### **2) AWS Cli**

1. Windows

    Windows Installer를 받아 설치합니다. ([64-bit](https://s3.amazonaws.com/aws-cli/AWSCLI64PY3.msi) or [32-bit](https://s3.amazonaws.com/aws-cli/AWSCLI32PY3.msi))

2. Linux

    ```bash
    # pip를 통해 설치
    $ pip install awscli
    ```

문서가 오래된 경우 [AWS CLI](https://aws.amazon.com/cli) 페이지를 참고해서 설치해주세요.

### 3) CFSSL

cfssl과 cfssljson을 [Release Page](https://github.com/cloudflare/cfssl/releases)에서 다운로드 합니다

## 2. Confituration
----

### AWS Credentials

[문서](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html)를 참고하여 AWS Credential을 발급받아 설정합니다.

## 3. Setup Terraform AWS provider & Terraform backend
----

### 1) Setup terraform local variables

```terraform
locals {
    region = <REGION>
    name   = <NAME>
    backup_bucket = <BUCKET_NAME>
}
```

### 2) Setup terraform & terraform backend
```terraform
terraform {
  required_version = "> 0.12.0"

  # PUBG S3 Terraform Backend
  backend "s3" {
    bucket = local.backup_bucket
    key    = "seminar/k8s-the-hard-way/${local.name}"
    region = "ap-northeast-2"
  }
}
```

### 3) Setup AWS provider

```terraform
provider "aws" {
  region = local.region
}
```