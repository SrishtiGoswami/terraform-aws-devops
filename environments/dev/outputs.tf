output "alb_dns_name" {
  description = "Public URL of the app (visit this in a browser)"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ec2_instance_id" {
  description = "Use with: aws ssm start-session --target <this>"
  value       = aws_instance.app.id
}

output "rds_endpoint" {
  description = "RDS connection endpoint (private, reachable only from the EC2 instance)"
  value       = aws_db_instance.main.address
}

output "rds_port" {
  value = aws_db_instance.main.port
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "db_password_ssm_path" {
  description = "Where the generated DB password lives (never in state/output in plaintext by default — use `terraform output -json` carefully, this just shows the path)"
  value       = aws_ssm_parameter.db_password.name
}
