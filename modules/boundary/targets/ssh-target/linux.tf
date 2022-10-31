data "aws_ami" "an_image" {
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  most_recent = true
  owners      = ["099720109477"]
}


resource "aws_instance" "linux" {
  ami                    = data.aws_ami.an_image.id
  instance_type          = "t3.micro"
  key_name               = var.aws_keypair_keyname
  subnet_id              = var.private_subnets[0]
  vpc_security_group_ids = [module.private-ssh.security_group_id]

  tags = {
    Name  = "${var.deployment_id}-linux"
    owner = var.owner
  }
}

