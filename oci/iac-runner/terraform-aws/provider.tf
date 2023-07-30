provider "aws" {}
provider "tls" {}
provider "null" {}
provider "helm" {}
provider "template" {}
provider "kubernetes" {}
provider "kubectl" {}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
    tls = {
      source  = "hashicorp/tls"
    }
    helm = {
      source = "hashicorp/helm"
    }
    local = {
      source = "hashicorp/local"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
  }
}
