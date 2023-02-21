resource "aws_db_subnet_group" "this" {
  name       = "${var.deployment_id}-b-subnet-group"
  subnet_ids = var.private_subnets

  tags = {
    Name = "boundary-database"
  }
}

resource "aws_db_instance" "this" {
  identifier             = "${var.deployment_id}-db"
  instance_class         = "db.t3.micro"
  allocated_storage      = 10
  engine                 = "postgres"
  engine_version         = "13.7"
  username               = var.rds_username
  password               = var.rds_password
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [module.rds-inbound-sg.security_group_id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = true
  skip_final_snapshot    = true
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.deployment_id}-grp"
  family = "postgres13"

  parameter {
    name  = "log_connections"
    value = "1"
  }
}

resource "null_resource" "create-db" {
  provisioner "remote-exec" {
    inline = [
      /* "sudo apt-get install -y postgresql-client", */
      /* "sleep 10", */
      "PGPASSWORD=postgres psql -h ${aws_db_instance.this.address} -U ${aws_db_instance.this.username} -c 'CREATE ROLE ANALYST NOINHERIT;'",
      "PGPASSWORD=postgres psql -h ${aws_db_instance.this.address} -U ${aws_db_instance.this.username} -c 'GRANT CONNECT ON DATABASE POSTGRES TO ANALYST;'",
      "PGPASSWORD=postgres psql -h ${aws_db_instance.this.address} -U ${aws_db_instance.this.username} -c 'GRANT USAGE ON SCHEMA PUBLIC TO ANALYST;'",
      "PGPASSWORD=postgres psql -h ${aws_db_instance.this.address} -U ${aws_db_instance.this.username} -c 'GRANT SELECT ON ALL TABLES IN SCHEMA PUBLIC TO ANALYST;'",
      "PGPASSWORD=postgres psql -h ${aws_db_instance.this.address} -U ${aws_db_instance.this.username} -c 'GRANT USAGE ON ALL SEQUENCES IN SCHEMA PUBLIC TO ANALYST;'",
      "PGPASSWORD=postgres psql -h ${aws_db_instance.this.address} -U ${aws_db_instance.this.username} -c 'GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA PUBLIC TO ANALYST;'",
      "PGPASSWORD=postgres psql -h ${aws_db_instance.this.address} -U ${aws_db_instance.this.username} -c 'CREATE ROLE DBA NOINHERIT;'",
      "PGPASSWORD=postgres psql -h ${aws_db_instance.this.address} -U ${aws_db_instance.this.username} -c 'GRANT CONNECT ON DATABASE POSTGRES TO DBA;'",
      "PGPASSWORD=postgres psql -h ${aws_db_instance.this.address} -U ${aws_db_instance.this.username} -c 'GRANT ALL PRIVILEGES ON DATABASE POSTGRES TO DBA;'",
      "PGPASSWORD=postgres psql -h ${aws_db_instance.this.address} -U ${aws_db_instance.this.username} -c 'GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA PUBLIC TO DBA;'",
      "PGPASSWORD=postgres psql -h ${aws_db_instance.this.address} -U ${aws_db_instance.this.username} -c \"CREATE TABLE COUNTRY(CODE VARCHAR, NAME VARCHAR);\"",
      "PGPASSWORD=postgres psql -h ${aws_db_instance.this.address} -U ${aws_db_instance.this.username} -c \"INSERT INTO COUNTRY VALUES('SG', 'SINGAPORE');\"",
      "sleep 5",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "PGPASSWORD=postgres psql -h ${aws_db_instance.this.address} -U ${aws_db_instance.this.username} -c 'GRANT SELECT ON ALL TABLES IN SCHEMA PUBLIC TO ANALYST;'",
      "PGPASSWORD=postgres psql -h ${aws_db_instance.this.address} -U ${aws_db_instance.this.username} -c 'GRANT ALL PRIVILEGES ON DATABASE POSTGRES TO DBA;'",
      "PGPASSWORD=postgres psql -h ${aws_db_instance.this.address} -U ${aws_db_instance.this.username} -c 'GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA PUBLIC TO DBA;'",
    ]
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = var.worker_ip
    private_key = trimspace(file("${path.root}/generated/ssh_key"))
  }

}
