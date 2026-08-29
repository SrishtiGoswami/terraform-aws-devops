############################################
# EC2 — application host
############################################

# Always resolves to the latest Amazon Linux 2023 AMI so we never
# hardcode (and forget to update) an AMI ID.
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "app" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  # No key_name — access is via SSM Session Manager only. No open
  # SSH port, no key pair to lose, no bastion host needed.

  user_data = templatefile("${path.module}/scripts/user_data.sh.tpl", {
    app_port = var.app_port
  })

  metadata_options {
    http_tokens = "required" # enforce IMDSv2
  }

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = "${var.project_name}-${var.environment}-app" }
}
