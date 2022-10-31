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
variable "org_id" {
  type = string
}
variable "project_id" {
  type = string
}
variable "vault_credstore_id" {
  type = string
}
variable "managed_group_analyst_id" {
  type = string
}
variable "managed_group_admin_id" {
  type = string
}
variable "rds_username" {
  type = string
}
variable "rds_password" {
  type = string
}
variable "worker_ip" {
  type = string
}
