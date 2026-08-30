#!/bin/bash
set -euo pipefail

# Amazon Linux 2023
dnf update -y
dnf install -y docker amazon-cloudwatch-agent rsyslog
systemctl enable --now docker
# AL2023 doesn't populate /var/log/messages without rsyslog — needed for
# the system-log half of Part 3.
systemctl enable --now rsyslog

# CloudWatch Agent config lives in SSM Parameter Store (see monitoring.tf),
# not baked into user_data, so it can be updated without touching EC2.
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s \
  -c ssm:/${project_name}/${environment}/cwagent/config

# Placeholder container so the ALB health check has something to pass
# against immediately after `terraform apply`. Part 2's CI/CD pipeline
# will later replace this with the real Flask app image via SSM
# Run Command (no SSH needed).
docker run -d \
  --name placeholder \
  --restart unless-stopped \
  -p ${app_port}:80 \
  nginxdemos/hello:plain-text