terraform {
  required_providers {
    auth0 = {
      source  = "auth0/auth0"
      version = "0.39.0"
    }
  }
}

provider "auth0" {
  domain        = var.auth0_domain
  client_id     = var.auth0_client_id
  client_secret = var.auth0_client_secret
  debug         = true
} 

provider "vault" {
  address = "http://${aws_instance.vault.public_ip}:8200"
  token = trimspace(file("${path.root}/generated/vault-token"))
}
