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
  default = "https://releases.ubuntu.com/26.04/ubuntu-26.04-live-server-amd64.iso"
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
  default = "nrt"
}

variable "vultr_plan_id" {
  type    = string
  default = "vc2-2c-4gb"
}

variable "vultr_snapshot_description" {
  type    = string
  default = "ubuntu2604-docker-compose-websaas-golden"
}

source "qemu" "ubuntu2604_docker_compose_websaas" {
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  output_directory = "output-ubuntu2604-docker-compose-websaas"
  shutdown_command = "echo 'packer' | sudo -S shutdown -P now"
  disk_size        = "40G"
  format           = "qcow2"
  accelerator      = "kvm"
  ssh_username     = "packer"
  ssh_password     = "packer"
  ssh_timeout      = "20m"
  vm_name          = "ubuntu2604-docker-compose-websaas-golden.qcow2"
  net_device       = "virtio-net"
  disk_interface   = "virtio"
  boot_wait        = "10s"
  boot_command = [
    "e<down><down><down><end>",
    " autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ",
    "<f10>"
  ]
  http_directory = "http"
}

build {
  sources = ["source.qemu.ubuntu2604_docker_compose_websaas"]

  provisioner "shell" {
    script = "scripts/setup-websaas-runtime.sh"
  }

  provisioner "shell" {
    script = "scripts/setup-observability-runtime.sh"
    environment_vars = ["INSTALL_POSTGRES_EXPORTER=1"]
  }

  provisioner "shell" {
    script = "scripts/cleanup-golden-image.sh"
  }
}

source "vultr" "ubuntu2604_docker_compose_websaas" {
  api_key              = var.vultr_api_key
  os_id                = var.vultr_os_id
  plan_id              = var.vultr_plan_id
  region_id            = var.vultr_region_id
  instance_label       = "packer-ubuntu2604-docker-compose-websaas"
  snapshot_description = var.vultr_snapshot_description
  state_timeout        = "30m"
  ssh_username         = "root"
  ssh_timeout          = "20m"
}

build {
  sources = ["source.vultr.ubuntu2604_docker_compose_websaas"]

  provisioner "shell" {
    script = "scripts/setup-websaas-runtime.sh"
  }

  provisioner "shell" {
    script = "scripts/setup-observability-runtime.sh"
    environment_vars = ["INSTALL_POSTGRES_EXPORTER=1"]
  }

  provisioner "shell" {
    script = "scripts/cleanup-golden-image.sh"
  }
}
