resource "boundary_managed_group" "db_admin" {
    name = "db_admin"
    description = "DB Admin managed group"
    auth_method_id = boundary_auth_method_oidc.auth0_oidc.id
    filter = "\"admin\" in \"/userinfo/org-roles\""
}

resource "boundary_managed_group" "db_analyst" {
    name = "db_analyst"
    description = "DB Analyst managed group"
    auth_method_id = boundary_auth_method_oidc.auth0_oidc.id
    filter = "\"analyst\" in \"/userinfo/org-roles\""
}