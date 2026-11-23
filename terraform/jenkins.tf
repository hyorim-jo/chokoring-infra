# 운영용 Jenkins

data "aws_ssm_parameter" "ubuntu_arm64" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/arm64/hvm/ebs-gp3/ami-id"
}

resource "aws_instance" "jenkins" {
  ami                    = data.aws_ssm_parameter.ubuntu_arm64.value
  instance_type          = "t4g.small"
  subnet_id              = "subnet-08d4e716f7647edb9"
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins.name

  # 외부로 나가는 통신용
  associate_public_ip_address = true

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    apt-get update
    apt-get install -y docker.io
    systemctl enable --now docker
    docker volume create jenkins_home
    docker run -d --name jenkins --restart unless-stopped \
      -p 127.0.0.1:8080:8080 \
      -v jenkins_home:/var/jenkins_home \
      -e JAVA_OPTS="-Xmx1g" \
      jenkins/jenkins:lts-jdk21
  EOF

  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = "chokoring-jenkins"
  }
}

resource "aws_security_group" "jenkins" {
  name        = "chokoring-jenkins"
  description = "Jenkins (SSM only, no inbound)"
  vpc_id      = "vpc-058c46af86b6d2f04"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "jenkins" {
  name = "chokoring-jenkins"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_instance_profile" "jenkins" {
  name = aws_iam_role.jenkins.name
  role = aws_iam_role.jenkins.name
}

resource "aws_iam_role_policy_attachment" "jenkins_ssm" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

output "jenkins_instance_id" {
  value = aws_instance.jenkins.id
}
