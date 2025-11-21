# # Packer Template for AWS - Cloud-Neutra Container VM (Ubuntu 22.04)

packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# Define the builder to create an AWS AMI
source "amazon-ebs" "ami-ubuntu-2204" {
  region                    = "ap-northeast-1"                          # AWS Region for the AMI
  ami_name                  = "Cloud-Neutra-Container-VM-2204-{{timestamp}}"
  instance_type             = "t3a.micro"                                # Instance type for AMI creation
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]                                     # Official Ubuntu AMI owner ID
  }
  ami_description           = "Containerized Ubuntu 22.04 with nerdctl, containerd, and monitoring tools"
  ssh_username              = "ubuntu"                                    # Default user for Ubuntu AMIs
  #ssh_private_key_file      = "~/.ssh/id_rsa"                       # SSH private key to connect (GitHub Secrets)
  run_tags                  = { "Name" = "Container-VM-2204" }

  tags = {
    "Environment"            = "Container"
    "Project"                = "Cloud-Neutra"
  }

  # AWS specific variables for network configuration
  subnet_id                = "subnet-0c98af564f030a473"                            # Specify subnet if needed
  vpc_id                   = "vpc-05e6af5f2bc7eb41b"                               # Specify VPC ID if needed
  associate_public_ip_address = true                                       # Optional for public IP
}

# Define the build block with provisioners and post-processors
build {
  name    = "Cloud-Neutra-Container-VM-2204"
  sources = [
    "source.amazon-ebs.ami-ubuntu-2204"
  ]

  # Provisioners to install and configure the system
  provisioner "shell" {
    inline = [
      # Enable all standard repositories
      "sudo add-apt-repository universe -y",
      "sudo add-apt-repository multiverse -y",
      "sudo add-apt-repository restricted -y",
      "sudo sed -i 's/# deb/deb/g' /etc/apt/sources.list",

      "sudo apt-get update",

      # Safe upgrade without kernel/bootloader risks
      "sudo apt-get dist-upgrade -y --no-install-recommends",

      # Remove unwanted packages
      "sudo apt-get remove --purge -y snapd resolvconf",
      "sudo rm -rf /var/cache/snapd/",
      "sudo rm -rf ~/snap",

      # Remove MOTD spam / cloud-init noise
      "sudo apt-get remove --purge -y landscape-common update-notifier-common motd-news-config",
      "sudo rm -rf /etc/update-motd.d/*",

      # Install required minimal tools
      "sudo apt-get install -y --no-install-recommends jq curl unzip gnupg lsb-release software-properties-common",

      # Install containerd
      "sudo apt-get install -y containerd",

      # Install nerdctl (for containerd orchestration)
      "curl -LO https://github.com/containerd/nerdctl/releases/download/v2.2.0/nerdctl-2.2.0-linux-amd64.tar.gz",
      "tar -xvzf nerdctl-2.2.0-linux-amd64.tar.gz",
      "sudo mv nerdctl /usr/local/bin/nerdctl",


      # Install monitoring tools

      # Install node_exporter (Prometheus Node Exporter)
      #"curl -s https://github.com/prometheus/node_exporter/releases/download/v1.10.2/node_exporter-1.10.2.linux-amd64.tar.gz | tar xz",
      #"sudo mv node_exporter-1.10.2.linux-amd64/node_exporter /usr/local/bin/",
      #"sudo systemctl enable node_exporter && sudo systemctl start node_exporter",

      # Install process_exporter
      #"curl -sL https://github.com/ncabatoff/process-exporter/releases/download/v0.8.7/process-exporter-0.8.7.linux-amd64.tar.gz  | tar xz",
      #"sudo mv process_exporter-0.8.7.linux-amd64/process_exporter /usr/local/bin/",
      #"sudo systemctl enable process_exporter && sudo systemctl start process_exporter",

      # Install Vector (log aggregation and processing)
      #"curl -LO https://github.com/vectordotdev/vector/releases/download/v0.51.1/vector_0.51.1-1_amd64.deb",
      #"sudo dpkg -i vector_0.51.1-1_amd64.deb",
      #"sudo systemctl enable vector && sudo systemctl start vector"
    ]
  }
}


