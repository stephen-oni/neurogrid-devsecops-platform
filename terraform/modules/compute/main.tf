# IAM Role & Instance Profile for Systems Manager (SSM) & ECR Access

resource "aws_iam_role" "ec2_ssm_role" {
  name = "neurogrid-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecr_policy" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "neurogrid-ec2-instance-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

# Ubuntu 22.04 LTS AMI Data Source

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical from the owner
}

# Launch Template

resource "aws_launch_template" "backend" {
  name_prefix   = "neurogrid-backend-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  vpc_security_group_ids = [var.app_security_group_id]

  # EC2 Instance with 2GB Swap space & Docker setup 
  user_data = base64encode(<<-EOF
              #!/bin/bash

              # Configure 2GB Swap file for stability

              fallocate -l 2G /swapfile
              chmod 600 /swapfile
              mkswap /swapfile
              swapon /swapfile
              echo '/swapfile none swap sw 0 0' >> /etc/fstab

              # Install official Docker, Docker Compose plugin, and AWS CLI

              apt-get update -y
              apt-get install -y ca-certificates curl gnupg unzip
              install -m 0755 -d /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
              chmod a+r /etc/apt/keyrings/docker.gpg
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
              apt-get update -y
              apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin awscli

              # Enable Docker without sudo

              systemctl enable --now docker
              usermod -aG docker ubuntu

              # Ensure Amazon SSM Agent is active

              snap start amazon-ssm-agent
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "neurogrid-backend-node"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group (Scalable 1 to 3, Default 2 across Private Subnets)

resource "aws_autoscaling_group" "backend_asg" {
  name_prefix         = "neurogrid-asg-"
  vpc_zone_identifier = var.private_app_subnet_ids

  min_size         = 1
  max_size         = 3
  desired_capacity = 1

  target_group_arns         = [var.alb_target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Target Tracking Scaling Policy to monitor 70% Average CPU Utilization

resource "aws_autoscaling_policy" "cpu_scaling_policy" {
  name                   = "neurogrid-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.backend_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}