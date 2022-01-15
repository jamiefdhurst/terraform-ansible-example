variable "SSH_PUBLIC_KEY" {
  type = string
  description = "Public key to use when deploying all AWS resources"
}

# Use the state we created earlier
terraform {
  required_version = ">= 0.14"
  backend "s3" {
    bucket          = "terraform-ansible-example-state"
    key             = "terraform.tfstate"
    region          = "eu-west-2"
    dynamodb_table  = "terraform-ansible-example-locks"
    encrypt         = true
  }
}

provider "null" {}
provider aws {
  region = "eu-west-2"
}

# Set up our key pair in KMS
resource "aws_key_pair" "root" {
  key_name   = "my-key-pair"
  public_key = var.SSH_PUBLIC_KEY
}

# Configure our VPC
resource "aws_default_vpc" "default" {
  tags = {
    name = "Default VPC"
  }
}

# Create a base security group
resource "aws_security_group" "default" {
  name        = "my-base"
  description = "Base security to allow SSH, and all private traffic"

  egress {
    description = "Allow all"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow from private"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = [aws_default_vpc.default.cidr_block]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an HTTP-specific security group
resource "aws_security_group" "http" {
  name        = "my-http"
  description = "Security group for HTTP/HTTPS"

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Get the latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

# Create the instance
resource "aws_instance" "ec2" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.root.key_name
  vpc_security_group_ids      = [aws_security_group.default.id, aws_security_group.http.id]
  associate_public_ip_address = true
  availability_zone           = "eu-west-2a"

  root_block_device {
    volume_type = "gp2"
    volume_size = 10
  }

  lifecycle {
    ignore_changes = [ami]
  }
  
  user_data = <<EOF
	#!/bin/bash
    sudo apt-get update
    sudo apt-get -y install python3 python3-docker python3-jenkins python3-boto3 awscli
	EOF

  tags = {
    Name = "my-instance"
  }
}

resource "null_resource" "ansible" {
  depends_on = [aws_instance.ec2]

  provisioner "local-exec" {
    command = "aws --region eu-west-2 ec2 wait instance-status-ok --instance-ids ${aws_instance.ec2.id} && ansible-playbook -e public_ip=${aws_instance.ec2.public_ip} -e private_ip=${aws_instance.ec2.private_ip} -e ansible_python_interpreter=/usr/bin/python3 -i ${aws_instance.ec2.public_ip}, ./ansible/my-instance.yml"
  }

  triggers = {
    always_run = timestamp()
  }
}

# Output the host once complete
output "hostname" {
  value = aws_instance.ec2.public_dns
}
