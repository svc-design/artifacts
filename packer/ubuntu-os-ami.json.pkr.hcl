variable "aws_accountId" {
  type    = string
  default = "837727238323"
}

variable "aws_region" {
  type    = string
  default = "cn-northwest-1"
}

locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }

source "amazon-ebs" "ubuntu" {
  ami_name      = "K3S-NeuVector-${local.timestamp}"
  instance_type = "t2.large"
  region        = "${var.aws_region}"
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["${var.aws_accountId}"]
  }
  ssh_username = "ubuntu"
}

build {
  sources = ["source.amazon-ebs.ubuntu"]
  provisioner "shell" {
    script = "./scripts/ubuntu/bootstrap.sh"
  }

}

packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}
