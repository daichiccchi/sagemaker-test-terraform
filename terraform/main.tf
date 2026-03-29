# ==============================================================================
# SageMaker Code Editor 環境構築
# ==============================================================================
# このファイルは、AWS SageMaker Code Editorを使用するための
# 完全なインフラストラクチャを定義します

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "SageMaker-Code-Editor"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# ==============================================================================
# データソース: 現在のAWSアカウント情報
# ==============================================================================
# なぜ必要？: IAMロールのポリシーなどでアカウントIDが必要になるため
data "aws_caller_identity" "current" {}

# なぜ必要？: 利用可能なアベイラビリティゾーンを動的に取得するため
data "aws_availability_zones" "available" {
  state = "available"
}
