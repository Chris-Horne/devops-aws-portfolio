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

# New: Create an IAM Role for the EC2 Instance to read from ECR
resource "aws_iam_role" "ec2_ecr_role" {
  name = "portfolio-ec2-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })
}

# Attach the official AWS ReadOnly policy for ECR to our role
resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  role       = aws_iam_role.ec2_ecr_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Create the final profile badge that attaches to the instance
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "portfolio-ec2-instance-profile"
  role = aws_iam_role.ec2_ecr_role.name
}


# 4. AWS EC2 Container Host
resource "aws_instance" "devops_server" {
  ami           = "ami-0c7217cdde317cfec" # Amazon Linux 2023 AMI in us-east-1
  instance_type = "t3.micro"
  key_name               = aws_key_pair.deployer_key.key_name 
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name # <--- Add this!


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
