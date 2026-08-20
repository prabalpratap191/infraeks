# IAM Policy for Jenkins User - KMS and CloudWatch Logs Permissions
# This policy grants the jenkins-user the necessary permissions to create
# and manage KMS keys and CloudWatch Log Groups for EKS cluster

resource "aws_iam_policy" "jenkins_eks_permissions" {
  name        = "JenkinsEKSAdditionalPermissionsUser"
  description = "Additional permissions for Jenkins user to create EKS cluster with KMS and CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KMSPermissions"
        Effect = "Allow"
        Action = [
          "kms:CreateKey",
          "kms:DescribeKey",
          "kms:GetKeyPolicy",
          "kms:PutKeyPolicy",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion",
          "kms:EnableKeyRotation",
          "kms:DisableKeyRotation",
          "kms:CreateAlias",
          "kms:DeleteAlias",
          "kms:UpdateAlias",
          "kms:ListAliases",
          "kms:ListResourceTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogsPermissions"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DescribeLogGroups",
          "logs:PutRetentionPolicy",
          "logs:DeleteLogGroup",
          "logs:ListTagsLogGroup",
          "logs:TagLogGroup",
          "logs:UntagLogGroup",
          "logs:TagResource",
          "logs:UntagResource"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Purpose   = "EKS Cluster Management"
    ManagedBy = "Terraform"
  }
}

# Attach the policy to jenkins-user
# Note: You need to import the existing jenkins-user or manage it separately
# Uncomment and configure the following if you want to manage the attachment:

 data "aws_iam_user" "jenkins" {
   user_name = "jenkins-user"
 }

 resource "aws_iam_user_policy_attachment" "jenkins_eks_permissions" {
   user       = data.aws_iam_user.jenkins.user_name
   policy_arn = aws_iam_policy.jenkins_eks_permissions.arn
 }
