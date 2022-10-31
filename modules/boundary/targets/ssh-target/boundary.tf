resource "boundary_host_catalog_static" "linux_servers" {
  name        = "linux_servers"
  description = "Linux servers"
  scope_id    = var.project_id
}

resource "boundary_host_static" "linux_servers" {
  name            = "linux_server_1"
  description     = "Linux Instance #1"
  address         = aws_instance.linux.private_ip
  host_catalog_id = boundary_host_catalog_static.linux_servers.id
}

resource "boundary_host_set_static" "linux_servers" {
  name            = "linux_host_set"
  description     = "Host set for Linux servers"
  host_catalog_id = boundary_host_catalog_static.linux_servers.id
  host_ids        = [boundary_host_static.linux_servers.id]
}


resource "boundary_credential_library_vault" "vault-ssh-key" {
  name                = "vault-ssh-key"
  description         = "Vault SSH Key"
  credential_store_id = var.vault_credstore_id
  path                = "secret/data/backend-sshkey" # change to Vault backend path
  http_method         = "GET"
  credential_type     = "ssh_private_key"
}

resource "boundary_role" "linux_admin" {
  name           = "linux_admin"
  description    = "Access to Linux hosts for admin role"
  scope_id       = var.org_id
  grant_scope_id = var.project_id
  grant_strings = [
    "id=${boundary_target.linux_admin.id};actions=read,authorize-session",
    "id=*;type=target;actions=list,no-op",
    "id=*;type=auth-token;actions=list,read:self,delete:self"
  ]
  principal_ids = [var.managed_group_admin_id]
}


resource "boundary_target" "linux_admin" {
  type                     = "ssh"
  name                     = "linux_admin"
  description              = "Linux host access for Admin"
  scope_id                 = var.project_id
  session_connection_limit = -1
  default_port             = 22
  worker_filter            = "\"worker\" in \"/tags/type\""
  host_source_ids = [
    boundary_host_set_static.linux_servers.id
  ]

  injected_application_credential_source_ids = [
    boundary_credential_library_vault.vault-ssh-key.id
  ]
}