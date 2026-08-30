variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Short name prefixed onto all resource names"
  type        = string
  default     = "devops-8byte"
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "dev"
}

# ---------- Networking ----------

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ). ALB requires 2+ AZs."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ), used for RDS"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "availability_zones" {
  description = "AZs to spread subnets across"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

# ---------- Compute ----------

variable "instance_type" {
  description = "EC2 instance type — t3.micro is free-tier eligible in most regions"
  type        = string
  default     = "t3.micro"
}

variable "app_port" {
  description = "Port the application container listens on"
  type        = number
  default     = 8080
}

# ---------- Database ----------

variable "db_name" {
  description = "Initial PostgreSQL database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for RDS"
  type        = string
  default     = "app_admin"
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class — db.t3.micro is free-tier eligible"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB — 20GB is within free tier"
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "PostgreSQL major version"
  type        = string
  default     = "16"
}

# ---------- Monitoring ----------

variable "alert_email" {
  description = "Email address that receives CloudWatch alarm notifications via SNS"
  type        = string
}

variable "log_retention_days" {
  description = "Retention period for CloudWatch Log Groups"
  type        = number
  default     = 7
}