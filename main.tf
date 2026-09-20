# main.tf
# This is the actual infrastructure. Terraform reads this, compares it to
# what currently exists in AWS (its "state"), and creates/changes only the
# difference. That's the core idea behind Infrastructure as Code:
# your infra becomes a diffable, version-controlled file instead of
# clicks you did once and forgot.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --- Networking ---
# Every AWS resource needs to live inside a VPC (Virtual Private Cloud) —
# think of it as your own isolated network inside AWS's data center.
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16" # ~65k private IP addresses available inside this VPC
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project_name}-vpc" }
}

# A subnet is a slice of the VPC's IP range, tied to one availability zone.
# "public" here means instances in it can get a public IP and reach the internet.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24" # 256 addresses
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = { Name = "${var.project_name}-public-subnet" }
}

# Without an Internet Gateway attached, nothing in the VPC can reach the
# internet at all — no apt-get, no docker pull, nothing.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

# Route table: tells the subnet "any traffic not meant for the local
# network (0.0.0.0/0) should go out through the internet gateway."
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# --- Security Group ---
# This is your firewall. Default AWS behavior is deny-all; every port you
# need has to be opened explicitly. Keep this list as short as possible —
# every open port is something an attacker can try.
resource "aws_security_group" "server_sg" {
  name        = "${var.project_name}-sg"
  description = "Allow SSH (you only), Jenkins UI, and Kubernetes API"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH — locked to your IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "Jenkins web UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.my_ip] # keep restricted; open to 0.0.0.0/0 only if you must demo it publicly
  }

  ingress {
    description = "Kubernetes API server (k3s)"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "App port, so you can view the deployed app"
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # this one's fine to open — it's your actual app, not an admin panel
  }

  egress {
    description = "Allow all outbound (needed for apt, docker pull, etc.)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-sg" }
}

# --- IAM ---
# An IAM role lets the EC2 instance itself call AWS APIs (e.g. to push to
# ECR) without you hardcoding access keys on the box — hardcoded keys are
# one of the most common real-world AWS security incidents.
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-profile"
  role = aws_iam_role.ec2_role.name
}

# --- Latest Ubuntu AMI lookup ---
# Instead of hardcoding an AMI ID (which changes per region and goes stale),
# ask AWS for the latest official Ubuntu 22.04 image at apply-time.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's official AWS account

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# --- The single EC2 instance ---
# Running Jenkins + Docker + k3s all on one box keeps this project cheap
# (one t3.medium instead of two). In a real company setup these would be
# separate machines — worth mentioning that tradeoff if asked in an interview.
resource "aws_instance" "server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.server_sg.id]
  key_name               = var.key_pair_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  root_block_device {
    volume_size = 20 # GB — default 8GB is too small once Docker images pile up
  }

  # Runs once on first boot. Bootstraps Docker, Jenkins, and k3s so you
  # don't have to SSH in and install everything by hand.
  user_data = file("${path.module}/user_data.sh")

  tags = { Name = "${var.project_name}-server" }
}

# --- S3 bucket ---
# Used here to store build artifacts / Terraform remote state in a real
# team setup. Included so the project touches S3 as listed in your skills.
resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.project_name}-artifacts-${data.aws_caller_identity.current.account_id}"
}

data "aws_caller_identity" "current" {}
