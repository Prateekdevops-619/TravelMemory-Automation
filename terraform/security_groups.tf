# ── Web Server Security Group ─────────────────────────────────────────────────

resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Allow HTTP/HTTPS from internet and SSH from your IP"
  vpc_id      = aws_vpc.main.id

  # HTTP
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Node.js backend (direct access for debugging)
  ingress {
    description = "Node.js backend port"
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_cidr]
  }

  # SSH — restricted to your IP only
  ingress {
    description = "SSH from admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-web-sg" }
}

# ── Database Server Security Group ────────────────────────────────────────────

resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "Allow MongoDB from web server and SSH via web server"
  vpc_id      = aws_vpc.main.id

  # MongoDB — only from web server SG
  ingress {
    description     = "MongoDB from web server"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  # SSH — only through the web server (bastion pattern)
  ingress {
    description     = "SSH from web server (bastion)"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-db-sg" }
}
