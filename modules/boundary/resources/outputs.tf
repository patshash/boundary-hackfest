output "project_id" {
  value = boundary_scope.project.id
}

output "org_id" {
  value = boundary_scope.org.id
}

output "managed_group_analyst_id" {
  value = boundary_managed_group.db_analyst.id
}

output "managed_group_admin_id" {
  value = boundary_managed_group.db_admin.id
}

output "static_credstore_id" {
  value = boundary_credential_store_static.static_cred_store.id
}

output "static_db_creds_id" {
  value = boundary_credential_username_password.static_db_creds.id
}