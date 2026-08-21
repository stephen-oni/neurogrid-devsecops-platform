# Ubuntu 22.04 LTS Canonical Official AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Monitoring Security Group (Fully locked down; access is handled privately over AWS SSM)
resource "aws_security_group" "monitoring_sg" {
  name        = "neurogrid-monitoring-sg"
  description = "Security group for Prometheus & Grafana host"
  vpc_id      = var.vpc_id

  # Outbound access for downloading Docker containers and OS updates via NAT/IGW
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "neurogrid-monitoring-sg"
  }
}

# IAM Role for Monitoring EC2 Host
resource "aws_iam_role" "monitoring_role" {
  name = "neurogrid-monitoring-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Allows Prometheus EC2 Service Discovery to query AWS APIs and auto-scrape ASG targets
resource "aws_iam_role_policy_attachment" "ec2_read_only" {
  role       = aws_iam_role.monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

# Allows secure private browser port forwarding and terminal access via AWS Systems Manager
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EC2 Instance Profile
resource "aws_iam_instance_profile" "monitoring_profile" {
  name = "neurogrid-monitoring-instance-profile"
  role = aws_iam_role.monitoring_role.name
}

# Dedicated Monitoring Server
resource "aws_instance" "monitoring" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.monitoring_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.monitoring_profile.name
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              set -e

              # Update system and install Docker & Docker Compose
              apt-get update -y
              apt-get install -y docker.io docker-compose-v2 unzip ca-certificates curl

              systemctl enable --now docker
              usermod -aG docker ubuntu

              # Ensure AWS SSM Agent is running for port-forwarding tunnels
              snap start amazon-ssm-agent || systemctl enable --now amazon-ssm-agent
              EOF

  tags = {
    Name        = "neurogrid-monitoring-host"
    Role        = "monitoring"
    Environment = "production"
  }
}