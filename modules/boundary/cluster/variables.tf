variable "hcp_boundary_cluster_id" {
  type = string
}

variable "hcp_boundary_admin" {
  type = string
}

variable "hcp_boundary_password" {
  type = string
}

variable "auth0_domain" {
  type = string
}

variable "auth0_client_id" {
  type = string
}

variable "auth0_client_secret" {
  type = string
}

variable "user_password" {
  type = string
}
variable "region" {
  default = "ap-south-1"
}

variable "deployment_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnets" {
  description = "Public subnets"
  type        = list(any)
}
variable "private_subnets" {
  description = "Private subnets"
  type        = list(any)
}
variable "owner" {
  type = string
}
variable "instance_type" {
  type = string
}
