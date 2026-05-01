# ── IAM Role for Web Server ───────────────────────────────────────────────────

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "web_server" {
  name               = "${var.project_name}-web-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = { Name = "${var.project_name}-web-role" }
}

# Allow the web server to read SSM parameters (useful for secrets retrieval)
resource "aws_iam_role_policy_attachment" "web_ssm_read" {
  role       = aws_iam_role.web_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

# Allow CloudWatch Logs so the app can ship logs
resource "aws_iam_role_policy_attachment" "web_cloudwatch" {
  role       = aws_iam_role.web_server.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "web_server" {
  name = "${var.project_name}-web-instance-profile"
  role = aws_iam_role.web_server.name
}

# ── IAM Role for Database Server ──────────────────────────────────────────────

resource "aws_iam_role" "db_server" {
  name               = "${var.project_name}-db-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = { Name = "${var.project_name}-db-role" }
}

# CloudWatch for DB metrics
resource "aws_iam_role_policy_attachment" "db_cloudwatch" {
  role       = aws_iam_role.db_server.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "db_server" {
  name = "${var.project_name}-db-instance-profile"
  role = aws_iam_role.db_server.name
}
