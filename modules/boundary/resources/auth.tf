resource "boundary_auth_method_oidc" "auth0_oidc" {
  scope_id             = boundary_scope.org.id
  name                 = "OIDC Authentication"
  description          = "OIDC auth method for Demo Organization"
  type                 = "oidc"
  issuer               = "https://${var.auth0_domain}/"
  client_id            = "${var.client_id}"
  client_secret        = "${var.client_secret}"
  callback_url         = "${var.boundary_cluster_url}/v1/auth-methods/oidc:authenticate:callback"
  api_url_prefix       = var.boundary_cluster_url
  signing_algorithms   = ["RS256"]
  is_primary_for_scope = true
  max_age              = 0
} 
