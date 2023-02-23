provider "alicloud" {
  region     = "ap-east-1"
}

terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "= 4.14.0"  
    }
    tls = {
      source  = "hashicorp/tls"
    }
  }
}
