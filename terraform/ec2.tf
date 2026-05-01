# ── Key Pair ──────────────────────────────────────────────────────────────────
# Generate a new RSA key pair managed by Terraform and store private key locally.

resource "tls_private_key" "travelmemory" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "travelmemory" {
  key_name   = var.key_pair_name
  public_key = tls_private_key.travelmemory.public_key_openssh

  tags = { Name = "${var.project_name}-keypair" }
}

# Write private key to disk so Ansible can use it
resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.travelmemory.private_key_pem
  filename        = "${path.module}/../ansible/${var.key_pair_name}.pem"
  file_permission = "0600"
}

# ── Web Server (public subnet) ────────────────────────────────────────────────

resource "aws_instance" "web" {
  ami                    = var.ami_id
  instance_type          = var.web_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.travelmemory.key_name
  iam_instance_profile   = aws_iam_instance_profile.web_server.name

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  # Minimal bootstrap: update packages and set hostname
  user_data = <<-EOF
    #!/bin/bash
    set -e
    hostnamectl set-hostname travelmemory-web
    apt-get update -y
    apt-get install -y python3 python3-pip
  EOF

  tags = { Name = "${var.project_name}-web-server" }
}

# ── Database Server (private subnet) ─────────────────────────────────────────

resource "aws_instance" "db" {
  ami                    = var.ami_id
  instance_type          = var.db_instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.db.id]
  key_name               = aws_key_pair.travelmemory.key_name
  iam_instance_profile   = aws_iam_instance_profile.db_server.name

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e
    hostnamectl set-hostname travelmemory-db
    apt-get update -y
    apt-get install -y python3 python3-pip
  EOF

  tags = { Name = "${var.project_name}-db-server" }
}
