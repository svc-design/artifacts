packer {
  required_plugins {
    qemu = {
      version = "~> 1.0"
      source  = "github.com/hashicorp/qemu"
    }
    vultr = {
      version = ">= 2.3.2"
      source  = "github.com/vultr/vultr"
    }
  }
}

variable "iso_url" {
  type    = string
  default = "https://cdimage.debian.org/cdimage/daily-builds/daily/arch-latest/amd64/iso-cd/debian-testing-amd64-netinst.iso"
}

variable "iso_checksum" {
  type    = string
  default = "none"
}

variable "vultr_api_key" {
  type      = string
  sensitive = true
  default   = env("VULTR_API_KEY")
}

variable "vultr_os_id" {
  type    = number
  default = 0
}

variable "vultr_region_id" {
  type    = string
  default = "ewr"
}

variable "vultr_plan_id" {
  type    = string
  default = "vc2-2c-4gb"
}

variable "vultr_snapshot_description" {
  type    = string
  default = "debian13-docker-compose-websaas-golden"
}

source "qemu" "debian13_docker_compose_websaas" {
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  output_directory = "output-debian13-docker-compose-websaas"
  shutdown_command = "echo 'packer' | sudo -S shutdown -P now"
  disk_size        = "20G"
  format           = "qcow2"
  accelerator      = "kvm"
  ssh_username     = "packer"
  ssh_password     = "packer"
  ssh_timeout      = "20m"
  vm_name          = "debian13-docker-compose-websaas-golden.qcow2"
  net_device       = "virtio-net"
  disk_interface   = "virtio"
  boot_wait        = "10s"
  boot_command = [
    "<esc><wait>",
    "install <wait>",
    " preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg <wait>",
    "debian-installer=en_US.UTF-8 <wait>",
    "auto <wait>",
    "locale=en_US.UTF-8 <wait>",
    "kbd-chooser/method=us <wait>",
    "keyboard-configuration/xkb-keymap=us <wait>",
    "netcfg/get_hostname=debian13-websaas <wait>",
    "netcfg/get_domain=local <wait>",
    "fb=false <wait>",
    "debconf/frontend=noninteractive <wait>",
    "console-setup/ask_detect=false <wait>",
    "console-keymaps-at/keymap=us <wait>",
    "grub-installer/bootdev=/dev/vda <wait>",
    "<enter><wait>"
  ]
  http_directory = "http"
}

build {
  sources = ["source.qemu.debian13_docker_compose_websaas"]

  provisioner "shell" {
    script = "scripts/setup-websaas-runtime.sh"
  }

  provisioner "shell" {
    script = "scripts/cleanup-golden-image.sh"
  }
}

source "vultr" "debian13_docker_compose_websaas" {
  api_key              = var.vultr_api_key
  os_id                = var.vultr_os_id
  plan_id              = var.vultr_plan_id
  region_id            = var.vultr_region_id
  instance_label       = "packer-debian13-docker-compose-websaas"
  snapshot_description = var.vultr_snapshot_description
  state_timeout        = "30m"
  ssh_username         = "root"
  ssh_timeout          = "20m"
}

build {
  sources = ["source.vultr.debian13_docker_compose_websaas"]

  provisioner "shell" {
    script = "scripts/setup-websaas-runtime.sh"
  }

  provisioner "shell" {
    script = "scripts/cleanup-golden-image.sh"
  }
}
