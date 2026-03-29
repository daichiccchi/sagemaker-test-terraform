# ==============================================================================
# IAMロールとポリシー設定
# ==============================================================================
# SageMakerが他のAWSサービスにアクセスするために必要な権限を定義

# ------------------------------------------------------------------------------
# SageMaker実行ロール
# ------------------------------------------------------------------------------
# なぜ必要？:
# SageMaker DomainとCode Editorは、S3、CloudWatch、ECRなどの
# 他のAWSサービスにアクセスする必要があります。
# このロールは、SageMakerがユーザーに代わってこれらのサービスを使用できるようにします。

resource "aws_iam_role" "sagemaker_execution_role" {
  name               = "${var.project_name}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.sagemaker_assume_role.json

  tags = {
    Name = "${var.project_name}-execution-role"
  }
}

# SageMakerサービスがこのロールを引き受けることを許可
data "aws_iam_policy_document" "sagemaker_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["sagemaker.amazonaws.com"]
    }
  }
}

# ------------------------------------------------------------------------------
# AWS管理ポリシーのアタッチ
# ------------------------------------------------------------------------------
# なぜ必要？:
# AWSが提供する事前定義済みポリシーで、一般的なSageMaker操作に必要な権限を含みます

# 1. SageMakerFullAccess - SageMakerの全機能へのアクセス
resource "aws_iam_role_policy_attachment" "sagemaker_full_access" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# 2. S3FullAccess - Code Editorでのファイル保存・読み込み、モデルの保存に必要
# 注意: 本番環境では、特定のS3バケットのみへのアクセスに制限すべきです
resource "aws_iam_role_policy_attachment" "s3_full_access" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# ------------------------------------------------------------------------------
# カスタムポリシー
# ------------------------------------------------------------------------------
# なぜ必要？:
# AWS管理ポリシーでカバーされない、特定の権限を追加

resource "aws_iam_role_policy" "sagemaker_custom_policy" {
  name   = "${var.project_name}-custom-policy"
  role   = aws_iam_role.sagemaker_execution_role.id
  policy = data.aws_iam_policy_document.sagemaker_custom_policy.json
}

data "aws_iam_policy_document" "sagemaker_custom_policy" {
  # CloudWatch Logs - ログの記録と監視
  statement {
    sid = "CloudWatchLogsAccess"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/sagemaker/*"]
  }

  # ECR - Dockerイメージの取得（カスタム環境を使用する場合）
  statement {
    sid = "ECRAccess"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]
    resources = ["*"]
  }

  # VPCアクセス - SageMakerがVPC内のリソースにアクセス
  statement {
    sid = "VPCAccess"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:CreateNetworkInterfacePermission",
      "ec2:DeleteNetworkInterface",
      "ec2:DeleteNetworkInterfacePermission",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeVpcs",
      "ec2:DescribeDhcpOptions",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups"
    ]
    resources = ["*"]
  }

  # SageMaker Studio/Code Editor固有の権限
  statement {
    sid = "SageMakerStudioAccess"
    actions = [
      "sagemaker:CreatePresignedDomainUrl",
      "sagemaker:DescribeDomain",
      "sagemaker:DescribeUserProfile",
      "sagemaker:ListTags"
    ]
    resources = ["*"]
  }
}
