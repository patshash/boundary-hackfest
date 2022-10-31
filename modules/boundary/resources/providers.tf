/* 
terraform {
  required_providers {
    boundary = {
      source  = "hashicorp/boundary"
      version = "1.0.12"
    }
  }
}

provider "boundary" {
  addr                            = var.boundary_cluster_url
  auth_method_id                  = trimspace(file("${path.root}/generated/global_auth_method_id"))
  password_auth_method_login_name = var.hcp_boundary_admin
  password_auth_method_password   = var.hcp_boundary_password
} 
*/
