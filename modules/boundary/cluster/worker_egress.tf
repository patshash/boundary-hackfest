resource "aws_instance" "boundary-worker-egress" {
  ami             = data.aws_ami.an_image.id
  instance_type   = var.instance_type
  key_name        = aws_key_pair.this.key_name
  subnet_id       = element(module.vpc.private_subnets, 1)
  security_groups = [module.worker-egress-inbound-sg.security_group_id]

  lifecycle {
    ignore_changes = all
  }

  tags = {
    Name  = "${var.deployment_id}-worker-egress"
    owner = var.owner
  }

  provisioner "file" {
    content     = filebase64("${path.root}/files/boundary/install.sh")
    destination = "/tmp/install_base64.sh"
  }

  provisioner "file" {
    content = templatefile("${path.root}/files/boundary/boundary-worker-egress.tpl", {
      boundary_cluster_id = trimspace(file("${path.root}/generated/boundary_cluster_id")),
      private_ip          = self.private_ip,
      upstream_worker_ip  = aws_instance.boundary-worker-ingress.private_ip
    })
    destination = "/tmp/boundary-worker.hcl"
  }

  provisioner "file" {
    content     = tls_private_key.ssh.private_key_openssh
    destination = "/home/ubuntu/ssh_key"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo base64 -d /tmp/install_base64.sh > /tmp/install.sh",
      "sudo mv /tmp/install.sh /home/ubuntu/install.sh",
      "sudo chmod +x /home/ubuntu/install.sh",
      "sudo chmod 400 /home/ubuntu/ssh_key",
      "sudo mkdir -p /etc/boundary/worker1",
      "sudo mv /tmp/boundary-worker.hcl /etc/boundary/boundary-worker.hcl",
      "sudo /home/ubuntu/install.sh worker",
      "sudo wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg",
      "sudo echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main\" | sudo tee /etc/apt/sources.list.d/hashicorp.list",
      "sudo apt update && sudo apt install vault",
      "sleep 20",
    ]
  }

  provisioner "local-exec" {
    command = <<-EOT
      ssh -o StrictHostKeyChecking=no -i ${path.root}/generated/${local.key_name} ubuntu@${aws_instance.boundary-worker-ingress.public_ip} "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /home/ubuntu/ssh_key ubuntu@${self.private_ip}:/etc/boundary/worker1/auth_request_token /home/ubuntu/worker_egress_auth_request_token"
      scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${path.root}/generated/${local.key_name} ubuntu@${aws_instance.boundary-worker-ingress.public_ip}:/home/ubuntu/worker_egress_auth_request_token ./generated/
      EOT
  }

  connection {
    bastion_host        = aws_instance.boundary-worker-ingress.public_ip
    bastion_user        = "ubuntu"
    agent               = false
    bastion_private_key = tls_private_key.ssh.private_key_openssh

    host        = self.private_ip
    user        = "ubuntu"
    private_key = tls_private_key.ssh.private_key_openssh
  }


  depends_on = [
    module.vpc,
    local_file.private_key
  ]
}



resource "null_resource" "register_worker_egress" {

  provisioner "local-exec" {
    command = "export BOUNDARY_ADDR=${hcp_boundary_cluster.this.cluster_url} && export AUTH_ID=$(boundary auth-methods list -scope-id global -format json | jq \".items[].id\" -r) && export BOUNDARY_AUTHENTICATE_PASSWORD_PASSWORD=${var.hcp_boundary_password} && boundary authenticate password -auth-method-id=$AUTH_ID -login-name=${var.hcp_boundary_admin} -password env://BOUNDARY_AUTHENTICATE_PASSWORD_PASSWORD && boundary workers create worker-led -scope-id global -worker-generated-auth-token=${trimspace(file("${path.root}/generated/worker_egress_auth_request_token"))}"
  }

  depends_on = [
    aws_instance.boundary-worker-egress
  ]
}

