locals {
  deployment_id = lower("${var.deployment_name}-${random_string.suffix.result}")
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

module "boundary-cluster" {
  source                  = "./modules/boundary/cluster"
  deployment_id           = local.deployment_id
  owner                   = var.owner
  hcp_boundary_cluster_id = local.deployment_id
  hcp_boundary_admin      = var.hcp_boundary_admin
  hcp_boundary_password   = var.hcp_boundary_password
  auth0_domain            = var.auth0_domain
  auth0_client_id         = var.auth0_client_id
  auth0_client_secret     = var.auth0_client_secret
  user_password           = var.user_password
  vpc_cidr                = var.aws_vpc_cidr
  public_subnets          = var.aws_public_subnets
  private_subnets         = var.aws_private_subnets
  instance_type           = var.aws_instance_type
}

module "boundary-resources" {
  source                = "./modules/boundary/resources"
  auth0_domain          = var.auth0_domain
  boundary_cluster_url  = module.boundary-cluster.hcp_boundary_cluster_url
  client_id             = module.boundary-cluster.auth0_client.client_id
  client_secret         = module.boundary-cluster.auth0_client.client_secret
  hcp_boundary_admin    = var.hcp_boundary_admin
  hcp_boundary_password = var.hcp_boundary_password
  depends_on = [
    module.boundary-cluster
  ]
}

module "vault-credstore" {
  source     = "./modules/boundary/vault-credstore"
  project_id = module.boundary-resources.project_id
  vault_ip   = module.boundary-cluster.vault_ip
}

module "db-target" {
  source                   = "./modules/boundary/targets/db-target"
  deployment_id            = local.deployment_id
  vpc_id                   = module.boundary-cluster.vpc_id
  vpc_cidr                 = module.boundary-cluster.vpc_cidr_block
  private_subnets          = module.boundary-cluster.private_subnets
  org_id                   = module.boundary-resources.org_id
  project_id               = module.boundary-resources.project_id
  rds_username             = var.rds_username
  rds_password             = var.rds_password
  vault_credstore_id       = module.vault-credstore.vault_credstore_id
  managed_group_admin_id   = module.boundary-resources.managed_group_admin_id
  managed_group_analyst_id = module.boundary-resources.managed_group_analyst_id
  worker_ip                = module.boundary-cluster.worker_ip
}

module "ssh-target" {
  source                 = "./modules/boundary/targets/ssh-target"
  deployment_id          = local.deployment_id
  vpc_id                 = module.boundary-cluster.vpc_id
  vpc_cidr               = module.boundary-cluster.vpc_cidr_block
  private_subnets        = module.boundary-cluster.private_subnets
  aws_keypair_keyname    = module.boundary-cluster.aws_keypair_keyname
  vault_credstore_id     = module.vault-credstore.vault_credstore_id
  org_id                 = module.boundary-resources.org_id
  project_id             = module.boundary-resources.project_id
  managed_group_admin_id = module.boundary-resources.managed_group_admin_id
  owner                  = var.owner
}

module "rdp-target" {
  source                      = "./modules/boundary/targets/rdp-target"
  deployment_id               = local.deployment_id
  vpc_id                      = module.boundary-cluster.vpc_id
  vpc_cidr                    = module.boundary-cluster.vpc_cidr_block
  private_subnets             = module.boundary-cluster.private_subnets
  aws_keypair_keyname         = module.boundary-cluster.aws_keypair_keyname
  vault_credstore_id          = module.vault-credstore.vault_credstore_id
  org_id                      = module.boundary-resources.org_id
  project_id                  = module.boundary-resources.project_id
  managed_group_analyst_id    = module.boundary-resources.managed_group_analyst_id
  managed_group_admin_id      = module.boundary-resources.managed_group_admin_id
  credlib_vault_db_admin_id   = module.db-target.credlib_vault_db_admin_id
  credlib_vault_db_analyst_id = module.db-target.credlib_vault_db_analyst_id
  owner                       = var.owner
}

module "k8s-target" {
  source                   = "./modules/boundary/targets/k8s-target"
  deployment_id            = local.deployment_id
  vpc_id                   = module.boundary-cluster.vpc_id
  vpc_cidr                 = module.boundary-cluster.vpc_cidr_block
  region                   = var.aws_region
  private_subnets          = module.boundary-cluster.private_subnets
  aws_keypair_keyname      = module.boundary-cluster.aws_keypair_keyname
  static_db_creds_id       = module.boundary-resources.static_db_creds_id
  org_id                   = module.boundary-resources.org_id
  project_id               = module.boundary-resources.project_id
  vault_credstore_id       = module.vault-credstore.vault_credstore_id
  managed_group_admin_id   = module.boundary-resources.managed_group_admin_id
  managed_group_analyst_id = module.boundary-resources.managed_group_analyst_id
  db_username              = var.hcp_boundary_admin
  db_password              = var.hcp_boundary_password
  hcp_boundary_address     = module.boundary-cluster.hcp_boundary_cluster_url
  hcp_boundary_admin       = var.hcp_boundary_admin
  hcp_boundary_password    = var.hcp_boundary_password
  owner                    = var.owner
}
