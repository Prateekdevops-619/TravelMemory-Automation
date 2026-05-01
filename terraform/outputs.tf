output "web_server_public_ip" {
  description = "Public IP address of the web server EC2 instance"
  value       = aws_instance.web.public_ip
}

output "web_server_public_dns" {
  description = "Public DNS of the web server"
  value       = aws_instance.web.public_dns
}

output "db_server_private_ip" {
  description = "Private IP address of the database EC2 instance"
  value       = aws_instance.db.private_ip
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "nat_gateway_ip" {
  description = "Elastic IP assigned to the NAT Gateway"
  value       = aws_eip.nat.public_ip
}

output "ssh_command_web" {
  description = "SSH command to connect to the web server"
  value       = "ssh -i ansible/${var.key_pair_name}.pem ubuntu@${aws_instance.web.public_ip}"
}

output "ssh_command_db_via_bastion" {
  description = "SSH command to connect to the DB server via the web server bastion"
  value       = "ssh -i ansible/${var.key_pair_name}.pem -J ubuntu@${aws_instance.web.public_ip} ubuntu@${aws_instance.db.private_ip}"
}

output "application_url" {
  description = "URL to access the TravelMemory application"
  value       = "http://${aws_instance.web.public_ip}"
}
