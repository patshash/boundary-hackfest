locals {
  key_name = "ssh-key"
  rsa_key_name = "rsa-key"
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

/* resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = "4096"
} */

resource "aws_key_pair" "this" {
  key_name   = "${var.deployment_id}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

/* resource "aws_key_pair" "rsa" {
  key_name   = "${var.deployment_id}-rsa-key"
  public_key = tls_private_key.rsa.public_key_openssh
} */

resource "local_file" "private_key" {
  content  = tls_private_key.ssh.private_key_openssh
  filename = "${path.root}/generated/${local.key_name}"

  provisioner "local-exec" {
    command = "chmod 400 ${path.root}/generated/${local.key_name}"
  }
}

resource "local_file" "private_rsa_key" {
  content  = tls_private_key.ssh.private_key_pem
  filename = "${path.root}/generated/${local.rsa_key_name}"

  provisioner "local-exec" {
    command = "chmod 400 ${path.root}/generated/${local.rsa_key_name}"
  }
}

data "aws_ami" "an_image" {
  most_recent = true
  owners      = ["self"]
  filter {
    name   = "name"
    values = ["${var.owner}-boundary-*"]
  }
}

resource "aws_instance" "boundary-worker" {
  ami             = data.aws_ami.an_image.id
  instance_type   = var.instance_type
  key_name        = aws_key_pair.this.key_name
  subnet_id       = element(module.vpc.public_subnets, 1)
  security_groups = [module.worker-inbound-sg.security_group_id]

  lifecycle {
    ignore_changes = all
  }

  tags = {
    Name  = "${var.deployment_id}-worker"
    owner = var.owner
  }

  provisioner "file" {
    content     = filebase64("${path.root}/files/boundary/install.sh")
    destination = "/tmp/install_base64.sh"
  }

  provisioner "file" {
    content = templatefile("${path.root}/files/boundary/boundary-worker.tpl", {
      boundary_cluster_id = trimspace(file("${path.root}/generated/boundary_cluster_id")),
      private_ip          = self.private_ip,
      public_ip           = self.public_ip
    })
    destination = "/tmp/boundary-worker.hcl"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo base64 -d /tmp/install_base64.sh > /tmp/install.sh",
      "sudo mv /tmp/install.sh /home/ubuntu/install.sh",
      "sudo chmod +x /home/ubuntu/install.sh",
      "sudo mkdir -p /etc/boundary/worker1",
      "sudo mv /tmp/boundary-worker.hcl /etc/boundary/boundary-worker.hcl",
      "sudo /home/ubuntu/install.sh worker",
      "sleep 20",
    ]
  }

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${path.root}/generated/${local.key_name} ubuntu@${self.public_ip}:/etc/boundary/worker1/auth_request_token ./generated/"
  }

  connection {
    host        = self.public_ip
    user        = "ubuntu"
    agent       = false
    private_key = tls_private_key.ssh.private_key_openssh
  }

  depends_on = [
    module.vpc,
    local_file.private_key
  ]
}

resource "null_resource" "register_worker" {

  provisioner "local-exec" {
    command = "export BOUNDARY_ADDR=${hcp_boundary_cluster.this.cluster_url} && export AUTH_ID=$(boundary auth-methods list -format json | jq \".items[].id\" -r) && export BOUNDARY_AUTHENTICATE_PASSWORD_PASSWORD=${var.hcp_boundary_password} && boundary authenticate password -auth-method-id=$AUTH_ID -login-name=${var.hcp_boundary_admin} -password env://BOUNDARY_AUTHENTICATE_PASSWORD_PASSWORD && boundary workers create worker-led -worker-generated-auth-token=${trimspace(file("${path.root}/generated/auth_request_token"))}"
  }

  depends_on = [
    aws_instance.boundary-worker
  ]
}