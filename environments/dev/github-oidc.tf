# --- GitHub Actions OIDC federation ---
# Lets CD workflows assume an AWS role with short-lived, auto-rotated
# credentials — no AWS access keys stored as GitHub secrets. Free (IAM has
# no charge for roles/providers).
#
# Copy this file into terraform/environments/dev/, set var.github_repo below
# (or wire it into variables.tf), then `terraform apply`.

variable "github_repo" {
  description = "GitHub repo allowed to assume the deploy role, as \"SrishtiGoswami/terraform-aws-devops\""
  type        = string
}

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Restrict to the main branch — PRs from forks/other branches can't deploy
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        # Legacy format (for older repos / docs)
        "repo:${var.github_repo}:ref:refs/heads/main",
        "repo:${var.github_repo}:environment:staging",
        "repo:${var.github_repo}:environment:production",

        # Immutable format (what your repo actually emits)
        "repo:SrishtiGoswami@85061371/terraform-aws-devops@1349548251:ref:refs/heads/main",
        "repo:SrishtiGoswami@85061371/terraform-aws-devops@1349548251:environment:staging",
        "repo:SrishtiGoswami@85061371/terraform-aws-devops@1349548251:environment:production",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions_deploy" {
  name               = "${var.project_name}-${var.environment}-gha-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
}

# Least-privilege: only what the deploy step in cd.yml actually calls.
data "aws_iam_policy_document" "github_actions_deploy_permissions" {
  statement {
    sid    = "SendSSMCommands"
    effect = "Allow"
    actions = [
      "ssm:SendCommand",
      "ssm:ListCommandInvocations",
      "ssm:GetCommandInvocation",
    ]
    resources = ["*"] # SendCommand doesn't support fine-grained resource ARNs for tag-based targeting
  }

  statement {
    sid       = "ReadDbParams"
    effect    = "Allow"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:*:*:parameter/${var.project_name}/${var.environment}/*"]
  }

  statement {
    sid       = "DecryptSecureStringParam"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["arn:aws:kms:*:*:alias/aws/ssm"]
    # Needed because db_password is a SecureString, encrypted with the
    # default AWS-managed SSM key (see rds.tf comment) — GetParameter
    # --with-decryption needs kms:Decrypt in addition to ssm:GetParameter.
  }
}

resource "aws_iam_role_policy" "github_actions_deploy_permissions" {
  name   = "deploy-permissions"
  role   = aws_iam_role.github_actions_deploy.id
  policy = data.aws_iam_policy_document.github_actions_deploy_permissions.json
}

output "github_actions_deploy_role_arn" {
  description = "Paste this into the GitHub repo secret AWS_DEPLOY_ROLE_ARN"
  value       = aws_iam_role.github_actions_deploy.arn
}
