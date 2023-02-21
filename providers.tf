terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.20.0"
    }
    boundary = {
      source  = "hashicorp/boundary"
      version = "1.1.4"
    }
    hcp = {
      source  = "hashicorp/hcp"
      version = "0.54.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "3.8.2"
    }
  }
}

provider "hcp" {
  client_id     = var.hcp_client_id
  client_secret = var.hcp_client_secret
}

provider "aws" {
  region = var.aws_region
}

provider "vault" {
  address = "http://127.0.0.1:8200"
  token = trimspace(file("${path.root}/generated/vault_token"))
  /* address = "http://${module.boundary-cluster.vault_ip}:8200" */
}

provider "boundary" {
  addr                            = module.boundary-cluster.hcp_boundary_cluster_url
  auth_method_id                  = trimspace(file("${path.root}/generated/global_auth_method_id"))
  password_auth_method_login_name = var.hcp_boundary_admin
  password_auth_method_password   = var.hcp_boundary_password
}
