#!/bin/bash
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install packer

mkdir -pv ~/.aws/
cat > ~/.aws/credentials << EOF
aws_access_key_id=XXXXXXXXXXXXXXXXX
aws_secret_access_key=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
EOF

cat > ~/.aws/config << EOF
[default]
region=cn-northwest-1
output=json
EOF

packer hcl2_upgrade ubuntu-ami.json

export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
export AWS_SECURITY_TOKEN
packer init .
packer fmt .
packer validate .
packer build ubuntu-ami.json.pkr.hcl
