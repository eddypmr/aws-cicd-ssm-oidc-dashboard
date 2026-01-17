# Terraform for Project 3 will go here (SSM + IAM Roles, no SSH)
terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = ">= 5.0"
        }
    }
}

provider "aws" {
    region = "eu-west-1"
}

locals {
    name = "eddy-p3"
}

# Amazon Linux 2023 (ssm parameter store)
data "aws_ssm_parameter" "ami" {
    name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

# ------------------------
# Red (VPC)
# ------------------------

resource "aws_vpc" "vpc" {
    cidr_block = "10.30.0.0/16"
    tags = {
        Name = "${local.name}-vpc"
    }
}

resource "aws_subnet" "public" {
    vpc_id                  = aws_vpc.vpc.id
    cidr_block              = "10.30.1.0/24"
    map_public_ip_on_launch = true
    availability_zone       = "eu-west-1a"
    tags = {
        Name = "${local.name}-subnet-public"
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.vpc.id
    tags = {
        Name = "${local.name}-igw"
    } 
}

resource "aws_route_table" "rt_public" {
    vpc_id = aws_vpc.vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }

    tags = {
        Name = "${local.name}-rt-public"
    }
}

resource "aws_route_table_association" "rta_public" {
    subnet_id      = aws_subnet.public.id
    route_table_id = aws_route_table.rt_public.id
}

# ------------------------
# Security Group (NO ssh)
# ------------------------
resource "aws_security_group" "sg" {
    name   = "${local.name}-sg"
    vpc_id = aws_vpc.vpc.id 

    ingress {
        description = "HTTP"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        description = "All outbound"
        from_port   = 0
        to_port     = 0
        protocol    = -1
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${local.name}-sg"
    }
}

# ------------------------
# IAM Role for EC2 (SSM)
# ------------------------
data "aws_iam_policy_document" "ec2_assume_role" {
    statement {
        actions = ["sts:AssumeRole"]
        principals {
            type        = "Service"
            identifiers = ["ec2.amazonaws.com"]
        }
    }
}

resource "aws_iam_role" "ec2_ssm_role" {
    name               = "${local.name}-ec2-ssm-role"
    assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

# AWS managed policy that allows SSM management
resource "aws_iam_role_policy_attachment" "ssm_core" {
    role       = aws_iam_role.ec2_ssm_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
    name = "${local.name}-ec2_profile"
    role = aws_iam_role.ec2_ssm_role.name
}


# ------------------------------------------------
# EC2 (Docker installed, SSM ready)
# ------------------------------------------------
resource "aws_instance" "ec2" {
    ami                         = data.aws_ssm_parameter.ami.value
    instance_type               = "t3.micro"
    subnet_id                   = aws_subnet.public.id
    vpc_security_group_ids      = [aws_security_group.sg.id]
    associate_public_ip_address = true
    iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name

    user_data = <<-EOF
                #!/bin/bash
                dnf update -y
                dnf install -y docker git
                systemctl enable docker
                systemctl start docker
                usermode -aG docker ec2-user

                # SSM Agent is preinstalled on Amazon Linux 2023 sure??
                systemctl enable amazon-ssm-agent
                systemctl start amazon-ssm-agent
                EOF
    
    tags = {
        Name = "${local.name}-ec2"
        Project = "project3-ssm-oidc"
    }
}

output "public_ip" {
    value = aws_instance.ec2.public_ip
}

output "instance_id" {
    value = aws_instance.ec2.id
}

output "web_url" {
    value = "http://${aws_instance.ec2.public_ip}"
}