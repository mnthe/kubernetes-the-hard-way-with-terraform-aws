#!/bin/bash

# 1. Check terraform
if ! [ -x "$(command -v terraform)" ]; then
    echo "Error: terraform not installed." >&2
    exit 1
fi

if ! [[ $(terraform version) == *"v0.12"* ]]; then
    echo "Error: Terraform Version Invalid, required: Terraform v0.12.xx, current: $(terraform version)" >&2
    exit 1
fi

# 2. Check aws-cli
if ! [ -x "$(command -v aws)" ]; then
    echo "Error: aws-cli not installed." >&2
    exit 1
fi

# 3. Check cfssl, cfssljson
if ! [ -x "$(command -v cfssl)" ]; then
    echo "Error: cfssl not installed." >&2
    exit 1
fi

if ! [ -x "$(command -v cfssljson)" ]; then
    echo "Error: cfssljson not installed." >&2
    exit 1
fi

# 4. Check kubectl
if ! [ -x "$(command -v kubectl)" ]; then
    echo "Error: kubectl not installed." >&2
    exit 1
fi

# 5. Check ssh, scp
if ! [ -x "$(command -v ssh)" ]; then
    echo "Error: ssh not installed." >&2
    exit 1
fi

if ! [ -x "$(command -v scp)" ]; then
    echo "Error: scp not installed." >&2
    exit 1
fi


# 99. All Done
echo "All Prerequisite Installed :D Well Done!!"
exit 0