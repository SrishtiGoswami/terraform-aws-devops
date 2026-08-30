############################################
# Monitoring & Logging (Part 3)
############################################

# ---------- SNS for alarm notifications ----------

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
  # AWS emails a confirmation link to alert_email after apply — you must
  # click it or the subscription stays "PendingConfirmation" and alarms
  # will fire silently into the void.
}

# ---------- Log groups ----------

resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.project_name}/${var.environment}/app"
  retention_in_days = var.log_retention_days
  tags              = { Name = "${var.project_name}-${var.environment}-app-logs" }
}

resource "aws_cloudwatch_log_group" "system" {
  name              = "/${var.project_name}/${var.environment}/system"
  retention_in_days = var.log_retention_days
  tags              = { Name = "${var.project_name}-${var.environment}-system-logs" }
}

# ---------- CloudWatch Agent config (mem/disk + system logs only —
# CPU/network are already emitted free by EC2, no agent needed there) ----------

locals {
  cw_agent_config = {
    metrics = {
      namespace = "CWAgent"
      metrics_collected = {
        mem = {
          measurement                 = ["mem_used_percent"]
          metrics_collection_interval = 60
        }
        disk = {
          measurement                 = ["used_percent"]
          resources                   = ["/"]
          metrics_collection_interval = 60
        }
      }
      append_dimensions = {
        InstanceId = "$${aws:InstanceId}"
      }
    }
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path       = "/var/log/messages"
              log_group_name  = aws_cloudwatch_log_group.system.name
              log_stream_name = "{instance_id}/var-log-messages"
            },
            {
              file_path       = "/var/log/cloud-init.log"
              log_group_name  = aws_cloudwatch_log_group.system.name
              log_stream_name = "{instance_id}/cloud-init"
            }
          ]
        }
      }
    }
  }
}

resource "aws_ssm_parameter" "cw_agent_config" {
  name  = "/${var.project_name}/${var.environment}/cwagent/config"
  type  = "String"
  value = jsonencode(local.cw_agent_config)
}

# ---------- Alarms ----------

resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-ec2-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "EC2 CPU above 80% for 15 minutes"
  dimensions          = { InstanceId = aws_instance.app.id }
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "ec2_mem_high" {
  alarm_name          = "${var.project_name}-${var.environment}-ec2-mem-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "EC2 memory above 85% for 15 minutes (via CloudWatch Agent)"
  dimensions          = { InstanceId = aws_instance.app.id }
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching" # agent takes a minute after boot to report
}

resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 2147483648 # 2 GiB in bytes
  alarm_description   = "RDS free storage below 2GB"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.main.identifier }
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_high" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "More than 10 5xx responses from the app in 5 minutes"
  dimensions          = { LoadBalancer = aws_lb.main.arn_suffix }
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "At least one unhealthy target behind the ALB for 2+ minutes"
  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}