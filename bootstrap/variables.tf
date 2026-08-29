variable "aws_region" {
  description = "AWS region to create the state bucket/table in"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Short project name, used as a prefix for resource names"
  type        = string
  default     = "devops-8byte"
}
