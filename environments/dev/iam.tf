############################################
# IAM for EC2 -> SSM (no SSH keys, no open port 22)
# Also grants read access to the SSM Parameter Store path
# where DB credentials are stored, so the app can fetch them
# at boot instead of them being baked into an AMI or user_data.
############################################

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${var.project_name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "read_app_params" {
  statement {
    actions = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = [
      "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/${var.environment}/*"
    ]
  }
}

resource "aws_iam_role_policy" "read_app_params" {
  name   = "${var.project_name}-read-app-params"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.read_app_params.json
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2.name
}
