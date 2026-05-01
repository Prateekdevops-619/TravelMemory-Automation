variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-west-2"
}

variable "availability_zone_public" {
  description = "AZ for the public subnet"
  type        = string
  default     = "eu-west-2a"
}

variable "availability_zone_private" {
  description = "AZ for the private subnet"
  type        = string
  default     = "eu-west-2b"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "web_instance_type" {
  description = "EC2 instance type for the web server"
  type        = string
  default     = "t2.micro"
}

variable "db_instance_type" {
  description = "EC2 instance type for the database server"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "Ubuntu 22.04 LTS AMI ID (eu-west-2)"
  type        = string
  default     = "ami-0e8cfa9c93340440d"
}

variable "key_pair_name" {
  description = "Name of the AWS key pair for SSH access"
  type        = string
  default     = "travelmemory-key"
}

variable "your_ip_cidr" {
  description = "Your public IP in CIDR notation for SSH access (e.g. 203.0.113.0/32)"
  type        = string
}

variable "project_name" {
  description = "Tag prefix applied to all resources"
  type        = string
  default     = "travelmemory"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "mongo_admin_password" {
  description = "MongoDB admin user password"
  type        = string
  sensitive   = true
}

variable "mongo_app_password" {
  description = "MongoDB application user password"
  type        = string
  sensitive   = true
}
