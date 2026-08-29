#!/bin/bash
set -euo pipefail

# Amazon Linux 2023
dnf update -y
dnf install -y docker
systemctl enable --now docker

# Placeholder container so the ALB health check has something to pass
# against immediately after `terraform apply`. Part 2's CI/CD pipeline
# will later replace this with the real Flask app image via SSM
# Run Command (no SSH needed).
docker run -d \
  --name placeholder \
  --restart unless-stopped \
  -p ${app_port}:80 \
  nginxdemos/hello:plain-text
