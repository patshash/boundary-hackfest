output "hcp_boundary_cluster_url" {
  value = hcp_boundary_cluster.this.cluster_url
}

output "auth0_client" {
  value = {
    client_id     = auth0_client.my_client.client_id,
    client_secret = auth0_client.my_client.client_secret
  }
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "vpc_cidr_block" {
  value = module.vpc.vpc_cidr_block
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "worker_ip" {
  value = aws_instance.boundary-worker.public_ip
}

output "vault_ip" {
  value = aws_instance.vault.public_ip
}

output "aws_keypair_keyname" {
  value = aws_key_pair.this.key_name
}
