provider "aws" {}
provider "tls" {}
provider "null" {}
provider "template" {}

terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
    }
    aws = {
      source  = "hashicorp/aws"
    }
    tls = {
      source  = "hashicorp/tls"
    }
  }
}
