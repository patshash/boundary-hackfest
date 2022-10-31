module "worker-inbound-sg" {
  source = "terraform-aws-modules/security-group/aws//modules/http-80"

  name        = "${var.deployment_id}-worker-inbound"
  description = "boundary-worker inbound sg"
  vpc_id      = module.vpc.vpc_id

  ingress_rules       = ["ssh-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 9202
      to_port     = 9202
      protocol    = "tcp"
      description = "boundary-worker proxy port"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}

module "vault-inbound-sg" {
  source = "terraform-aws-modules/security-group/aws//modules/http-80"

  name                = "${var.deployment_id}-vault-allow_inbound"
  description         = "Vault inbound sg"
  vpc_id              = module.vpc.vpc_id
  ingress_rules       = ["ssh-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 8200
      to_port     = 8200
      protocol    = "tcp"
      description = "vault api ports"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}  
