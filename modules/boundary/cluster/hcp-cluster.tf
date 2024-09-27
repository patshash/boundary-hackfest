resource "hcp_boundary_cluster" "this" {
  cluster_id = var.hcp_boundary_cluster_id
  username   = var.hcp_boundary_admin
  password   = var.hcp_boundary_password
  tier       = var.hcp_boundary_tier
}

resource "null_resource" "auth_method_id" {
  provisioner "local-exec" {
    command = "curl -s ${hcp_boundary_cluster.this.cluster_url}/v1/auth-methods?scope_id=global | jq \".items[].id\" -r > ${path.root}/generated/global_auth_method_id"
  }
  
  provisioner "local-exec" {
    command = "echo ${hcp_boundary_cluster.this.cluster_url} | awk -F'/' '{print $3}' | awk -F'.' '{print $1}' > ${path.root}/generated/boundary_cluster_id"
  }

  depends_on = [
    hcp_boundary_cluster.this
  ]
}