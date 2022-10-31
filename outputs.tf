output "deployment_id" {
  value = local.deployment_id
}

output "hcp_boundary_cluster_url" {
  value = module.boundary-cluster.hcp_boundary_cluster_url
}

output "hcp_boundary_admin" {
  value = {
    username = var.hcp_boundary_admin,
    password = var.hcp_boundary_password
  }
}

output "auth0_client" {
  value     = module.boundary-cluster.auth0_client
  sensitive = true
}

output "worker_ip" {
  value = module.boundary-cluster.worker_ip
}

output "vault_ip" {
  value = module.boundary-cluster.vault_ip
}
/*
output "linux_ip" {
  value = module.infra-aws.linux_ip
}

output "windows_ip" {
  value = module.infra-aws.windows_ip
}

output "rds" {
  value = {
    host     = module.infra-aws.rds_hostname,
    port     = module.infra-aws.rds_port,
    username = var.rds_username,
    password = var.rds_password
  }
  sensitive = true
}

output "aws_secret_access_key" {
  value = var.aws_secret_access_key
  sensitive = true
}
*/