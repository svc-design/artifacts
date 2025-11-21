###############################################################
# Cloud-Neutra AWS AMI Builder (Multi-Arch / Multi-LTS)
# This file is the COMMON builder template inherited by:
#   base / container / k3s / sealos / sealos-gpu
###############################################################

packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

###############################################################
# Input Variables
###############################################################
variable "cpu_arch" {
  type        = string
  description = "CPU architecture (amd64 or arm64)"
  default     = "amd64"
}

###############################################################
# Locals — override `edition` / `ubuntu_version` in edition-specific template
###############################################################

locals {
  edition        = lookup(var, "edition", "container")
  ubuntu_version = lookup(var, "ubuntu_version", "2204")

  arch_map = {
    amd64 = "amd64"
    arm64 = "arm64"
  }

  ubuntu_codename = lookup(
    {
      "2204" = "jammy"
      "2404" = "noble"
    },
    local.ubuntu_version,
    "unknown"
  )

  ubuntu_version_dot = lookup(
    {
      "2204" = "22.04"
      "2404" = "24.04"
    },
    local.ubuntu_version,
    "unknown"
  )
}

###############################################################
# AMI Builder
###############################################################
source "amazon-ebs" "this" {
  region = "ap-northeast-1"

  # Arm = t4g, AMD64 = t3
  instance_type = var.cpu_arch == "arm64" ? "t4g.micro" : "t3.micro"

  ami_name        = "Cloud-Neutra-${local.edition}-VM-${local.ubuntu_version}-${var.cpu_arch}-{{timestamp}}"
  ami_description = "Cloud-Neutra ${local.edition} image Ubuntu ${local.ubuntu_version} ${var.cpu_arch}"
  ssh_username    = "ubuntu"

  ###############################################################
  # Official Ubuntu AMI Filter (AWS official image name pattern)
  #
  # Example name pattern:
  # ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20240229
  ###############################################################
  source_ami_filter {
    filters = {
      name = "ubuntu/images/*ubuntu-${local.ubuntu_codename}-${local.ubuntu_version_dot}-${local.arch_map[var.cpu_arch]}-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical
  }

  ###############################################################
  # Tags
  ###############################################################
  tags = {
    Project      = "Cloud-Neutra"
    OS           = "Ubuntu ${local.ubuntu_version}"
    Edition      = local.edition
    Architecture = var.cpu_arch
    Role         = "Golden-Image"
  }

  run_tags = {
    Name = "CN-${local.edition}-${local.ubuntu_version}-${var.cpu_arch}"
  }
}

###############################################################
# Build Script Pipeline (Standardized)
###############################################################
build {
  name    = "Cloud-Neutra-${local.edition}-VM-${local.ubuntu_version}"
  sources = ["source.amazon-ebs.this"]

  provisioner "shell" {
    script = "packer/scripts/base/01_os_base.sh"
  }

  provisioner "shell" {
    script = "packer/scripts/base/02_hardening.sh"
  }

  provisioner "shell" {
    script = "packer/scripts/flavors/${local.edition}.sh"
  }

  provisioner "shell" {
    script = "packer/scripts/common/cleanup.sh"
  }
}
