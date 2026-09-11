# 1. Terraform Provider Configuration
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# 2. AWS Elastic Container Registry (ECR)
resource "aws_ecr_repository" "portfolio_app_repo" {
  name                 = "devops-portfolio-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# 3. AWS Security Group (Allows SSH & HTTP Web Traffic)
resource "aws_security_group" "web_sg" {
  name        = "portfolio-web-sg"
  description = "Allow inbound HTTP and SSH traffic"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# New: Register your public SSH key with AWS
resource "aws_key_pair" "deployer_key" {
  key_name   = "portfolio-deployer-key"
  public_key = file("~/.ssh/id_rsa.pub")
}


# 4. AWS EC2 Container Host
resource "aws_instance" "devops_server" {
  ami           = "ami-0c7217cdde317cfec" # Amazon Linux 2023 AMI in us-east-1
  instance_type = "t3.micro"
  key_name               = aws_key_pair.deployer_key.key_name 
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name = "DevOps-Portfolio-Host"
  }
}

# 5. Infrastructure Outputs
output "server_public_ip" {
  description = "The public IP address of the EC2 container host"
  value       = aws_instance.devops_server.public_ip
}

# 6. Automatically Generate Ansible Inventory
resource "local_file" "ansible_inventory" {
  filename = "./inventory.ini"
  content  = <<EOF
[portfolio_servers]
${aws_instance.devops_server.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
EOF
}
