variable "deployment_id" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "vpc_cidr" {
  type = string
}
variable "private_subnets" {
  description = "Private subnets"
  type        = list(any)
}
variable "aws_keypair_keyname" {
  type = string
}
variable "owner" {
  type = string
}
variable "static_db_creds_id" {
  type = string
}
variable "managed_group_admin_id" {
  type = string
}
variable "project_id" {
  type = string
}
variable "org_id" {
  type = string
}
variable "db_username" {
  type = string
}
variable "db_password" {
  type = string
}
variable "region" {
  type = string
}
variable "hcp_boundary_address" {
  type = string
}
variable "hcp_boundary_admin" {
  type = string
}
variable "hcp_boundary_password" {
  type = string
}