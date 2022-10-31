resource "aws_instance" "windows" {
  ami                    = "ami-0b204ba02c86d0218"
  instance_type          = "t3.micro"
  key_name               = var.aws_keypair_keyname
  subnet_id              = var.private_subnets[0]
  vpc_security_group_ids = [module.private-rdp.security_group_id]

  tags = {
    Name  = "${var.deployment_id}-windows"
    owner = var.owner
  }
}