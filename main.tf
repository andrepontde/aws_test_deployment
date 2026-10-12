terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# Fetch the EC2 Instance Connect IP range
data "aws_ip_ranges" "ec2_instance_connect" {
  services = ["EC2_INSTANCE_CONNECT"]
  regions  = [var.aws_region]
}

# Fetch the latest Ubuntu 26.04 LTS AMI from Canonical
data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/26.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# Create a Security Group to allow HTTP (80) and SSH (22) traffic
resource "aws_security_group" "server_sg" {
  name        = "server-allow-http"
  description = "Allow inbound HTTP and SSH traffic"

  ingress {
    description = "HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = data.aws_ip_ranges.ec2_instance_connect.cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Provision an EC2 Instance
resource "aws_instance" "server" {
  ami           = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.server_sg.id]
  user_data = <<-EOF
  #!/bin/bash
  # Install your Python environment
  apt-get update -y
  apt-get install -y python3.14-venv
  apt install uvicorn
  apt install python3-pip
  python3.14 -m venv venv
  source venv/bin/activate

  # Clon the latest app directly onto the server
  git clone https://github.com/andrepontde/aws_test_deployment.git
  cd aws_test_deployment/Backend
  pip install -r requirements.txt

  # Run Uvicorn on port 80 bound to all interfaces
  uvicorn main:app --host 0.0.0.0 --port 80 > uvicorn.log 2>&1 &
  EOF

  tags = {
    Name = var.instance_name
  }
}

# Output the public IP address
output "public_ip" {
  value       = "${aws_instance.server.public_ip}"
  description = "The public IP of your application"
}
