# ==============================================================================
# 変数定義
# ==============================================================================

variable "aws_region" {
  description = "AWSリージョン"
  type        = string
  default     = "ap-northeast-1" # 東京リージョン
}

variable "environment" {
  description = "環境名 (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "プロジェクト名（リソース名のプレフィックスとして使用）"
  type        = string
  default     = "sagemaker-code-editor"
}

# ------------------------------------------------------------------------------
# ネットワーク設定
# ------------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "VPCのCIDRブロック"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "パブリックサブネットのCIDRブロック"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "プライベートサブネットのCIDRブロック"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

# ------------------------------------------------------------------------------
# SageMaker設定
# ------------------------------------------------------------------------------

variable "sagemaker_instance_type" {
  description = "SageMaker Code Editorのインスタンスタイプ"
  type        = string
  default     = "ml.t3.medium" # 開発用の小さめインスタンス
}

variable "sagemaker_volume_size" {
  description = "SageMaker Code EditorのEBSボリュームサイズ (GB)"
  type        = number
  default     = 50
}

variable "user_profile_name" {
  description = "SageMakerユーザープロファイル名"
  type        = string
  default     = "default-user"
}
