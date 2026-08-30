############################################
# Dashboards (Part 3 requires at least 2)
############################################

resource "aws_cloudwatch_dashboard" "infra" {
  dashboard_name = "${var.project_name}-${var.environment}-infra"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title   = "EC2 CPU Utilization"
          view    = "timeSeries"
          region  = var.aws_region
          metrics = [["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.app.id]]
          period  = 300, stat = "Average"
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title  = "EC2 Memory & Disk Used % (CloudWatch Agent)"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            ["CWAgent", "mem_used_percent", "InstanceId", aws_instance.app.id],
            ["CWAgent", "disk_used_percent", "InstanceId", aws_instance.app.id, "path", "/", "fstype", "xfs"]
          ]
          period = 300, stat = "Average"
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title  = "RDS CPU & Connections"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.main.identifier],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.main.identifier]
          ]
          period = 300, stat = "Average"
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title   = "RDS Free Storage Space (bytes)"
          view    = "timeSeries"
          region  = var.aws_region
          metrics = [["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", aws_db_instance.main.identifier]]
          period  = 300, stat = "Average"
        }
      },
      {
        type = "metric", x = 0, y = 12, width = 24, height = 6
        properties = {
          title  = "ALB Target Health"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", aws_lb.main.arn_suffix, "TargetGroup", aws_lb_target_group.app.arn_suffix],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", aws_lb.main.arn_suffix, "TargetGroup", aws_lb_target_group.app.arn_suffix]
          ]
          period = 60, stat = "Average"
        }
      }
    ]
  })
}

resource "aws_cloudwatch_dashboard" "app" {
  dashboard_name = "${var.project_name}-${var.environment}-app"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title   = "Request Count"
          view    = "timeSeries"
          region  = var.aws_region
          metrics = [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix]]
          period  = 60, stat = "Sum"
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title  = "Response Codes (2xx / 4xx / 5xx from target)"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", aws_lb.main.arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", aws_lb.main.arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.main.arn_suffix]
          ]
          period = 60, stat = "Sum"
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title  = "Target Response Time (latency, seconds)"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "p50", label = "p50" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "p99", label = "p99" }]
          ]
          period = 60
        }
      },
      {
        type = "log", x = 12, y = 6, width = 12, height = 6
        properties = {
          title  = "Recent App Log Errors"
          region = var.aws_region
          query  = "SOURCE '${aws_cloudwatch_log_group.app.name}' | fields @timestamp, @message | sort @timestamp desc | limit 50"
          view   = "table"
        }
      }
    ]
  })
}