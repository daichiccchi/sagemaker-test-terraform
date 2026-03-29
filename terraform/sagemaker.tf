# ==============================================================================
# SageMaker Domain とユーザープロファイル
# ==============================================================================

# ------------------------------------------------------------------------------
# SageMaker Domain
# ------------------------------------------------------------------------------
# なぜ必要？:
# SageMaker Domainは、SageMaker Studio、Code Editor、JupyterLabなどの
# 統合開発環境を提供するための「組織・プロジェクトの枠組み」です。
#
# 重要な概念:
# - Domain自体はインスタンスではなく、設定の集合体
# - 複数のユーザー（User Profile）が共有できる
# - ユーザーがアプリ（Code Editor等）を起動した時に、初めてインスタンスが起動
# - Domain作成自体は無料（EFSストレージと起動したインスタンスのみ課金）
#
# 主な機能:
# - ユーザー管理とアクセス制御
# - 共有ストレージ (EFS) の自動提供
# - ネットワークとセキュリティ設定
# - JupyterLab、Code Editor、Canvasなどのアプリケーションホスティング

resource "aws_sagemaker_domain" "main" {
  domain_name = "${var.project_name}-domain"
  auth_mode   = "IAM" # IAM認証を使用（他にSSO認証も選択可能）
  vpc_id      = aws_vpc.main.id
  subnet_ids  = aws_subnet.private[*].id

  # ------------------------------------------------------------------------------
  # ネットワークアクセスタイプ
  # ------------------------------------------------------------------------------
  # VpcOnly: VPC内部からのみアクセス可能（セキュアだが、Direct Internet接続なし）
  # PublicInternetOnly: インターネット経由でアクセス可能（非推奨）
  app_network_access_type = "VpcOnly"

  # ------------------------------------------------------------------------------
  # EFS (Elastic File System) について
  # ------------------------------------------------------------------------------
  # EFSは自動的に作成されます。明示的な指定は不要です。
  #
  # 自動作成されるもの:
  # - ユーザーごとのホームディレクトリ (/home/sagemaker-user/)
  # - Code Editorのワークスペース
  # - JupyterLabのノートブック
  # - ユーザー設定ファイル
  #
  # EFSの特徴:
  # - 自動スケール（最大8 EiB）
  # - 使用した分だけ課金（$0.30/GB/月 in ap-northeast-1）
  # - 高可用性（複数AZに自動レプリケーション）
  #
  # Domain削除時の挙動を制御する場合:
  # retention_policy {
  #   home_efs_file_system = "Retain"  # Domainを削除してもEFSを保持（デフォルトは "Delete"）
  # }

  # ------------------------------------------------------------------------------
  # デフォルト設定: すべてのユーザーに適用される基本設定
  # ------------------------------------------------------------------------------
  default_user_settings {
    # 実行ロール: SageMakerがAWSリソースにアクセスするための権限
    execution_role = aws_iam_role.sagemaker_execution_role.arn

    # セキュリティグループ: ネットワークアクセス制御
    security_groups = [aws_security_group.sagemaker.id]

    # ------------------------------------------------------------------------------
    # Code Editor 設定（今回のメイン）
    # ------------------------------------------------------------------------------
    # なぜ必要？:
    # Code Editorは、VS Code風のインターフェースを持つ開発環境です。
    # - 本格的なコード開発に適している
    # - Git統合
    # - ターミナルアクセス
    # - 拡張機能のサポート（制限あり）
    #
    # 起動時の動作:
    # ユーザーがCode Editorを起動すると、指定したインスタンスタイプのEC2インスタンスが
    # 自動的に起動し、VS Code Serverがデプロイされます。
    #
    # 注意: Code Editorは、sagemaker_image_arnを指定せず、デフォルトイメージを使用します
    code_editor_app_settings {
      default_resource_spec {
        instance_type = var.sagemaker_instance_type
      }
    }

    # ------------------------------------------------------------------------------
    # JupyterLab設定（オプション）
    # ------------------------------------------------------------------------------
    # Code Editorと併用可能です。ノートブック中心の作業に適しています。
    # JupyterLabもデフォルトイメージを使用します
    jupyter_lab_app_settings {
      default_resource_spec {
        instance_type = var.sagemaker_instance_type
      }
    }

    # ------------------------------------------------------------------------------
    # カーネルゲートウェイ設定（ノートブック実行用）
    # ------------------------------------------------------------------------------
    # なぜ必要？:
    # JupyterノートブックのPythonカーネルを実行するための設定。
    # ノートブックUIとカーネル実行環境を分離することで、リソース管理が柔軟になります。
    #
    # カーネルゲートウェイには、Data Science用のイメージを使用できます
    kernel_gateway_app_settings {
      default_resource_spec {
        instance_type = var.sagemaker_instance_type
        # カーネル実行用に適切なイメージを指定（オプション）
        # デフォルトを使う場合はコメントアウト
        # sagemaker_image_arn = "arn:aws:sagemaker:${var.aws_region}:..."
      }
    }

    # ------------------------------------------------------------------------------
    # 共有設定
    # ------------------------------------------------------------------------------
    sharing_settings {
      # ノートブックの出力タイプ設定
      notebook_output_option = "Allowed" # "Disabled"にすると出力が保存されない
      s3_output_path         = "s3://${aws_s3_bucket.sagemaker_data.bucket}/notebook-outputs"
    }
  }

  # ------------------------------------------------------------------------------
  # Domain設定
  # ------------------------------------------------------------------------------
  domain_settings {
    # セキュリティグループID（VPC内の通信制御）
    security_group_ids = [aws_security_group.sagemaker.id]
  }

  tags = {
    Name = "${var.project_name}-domain"
  }

  # リソースの依存関係を明示
  depends_on = [
    aws_iam_role_policy_attachment.sagemaker_full_access,
    aws_iam_role_policy_attachment.s3_full_access,
    aws_iam_role_policy.sagemaker_custom_policy
  ]
}

# ------------------------------------------------------------------------------
# 注意: SageMaker イメージについて
# ------------------------------------------------------------------------------
# Code EditorやJupyterLabは、AWSが管理するデフォルトイメージを自動的に使用します。
# カスタムイメージを使用する場合は、以下の手順が必要です:
# 1. ECRにカスタムイメージをプッシュ
# 2. aws_sagemaker_image リソースでイメージを登録
# 3. aws_sagemaker_app_image_config でイメージ設定を作成
# 4. default_resource_spec で sagemaker_image_arn を指定
#
# 今回は、デフォルトイメージを使用するため、これらの設定は不要です。

# ------------------------------------------------------------------------------
# S3バケット（SageMakerデータ保存用）
# ------------------------------------------------------------------------------
# なぜ必要？:
# EFSとは別に、以下の用途でS3ストレージが必要です:
# - ノートブックの出力保存（大容量データ）
# - MLモデルの保存・バージョン管理
# - データセットの保存（長期保存、コスト効率）
# - Code Editorからのファイルエクスポート
#
# EFS vs S3の使い分け:
# - EFS: 頻繁にアクセスするファイル、リアルタイム編集
# - S3: アーカイブ、大容量データ、長期保存

resource "aws_s3_bucket" "sagemaker_data" {
  bucket = "${var.project_name}-data-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-data-bucket"
  }
}

# S3バケットのバージョニング有効化（データ保護・誤削除対策）
resource "aws_s3_bucket_versioning" "sagemaker_data" {
  bucket = aws_s3_bucket.sagemaker_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3バケットの暗号化設定（セキュリティ強化）
resource "aws_s3_bucket_server_side_encryption_configuration" "sagemaker_data" {
  bucket = aws_s3_bucket.sagemaker_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# パブリックアクセスブロック設定（セキュリティ強化）
resource "aws_s3_bucket_public_access_block" "sagemaker_data" {
  bucket = aws_s3_bucket.sagemaker_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ==============================================================================
# SageMaker User Profile
# ==============================================================================
# なぜ必要？:
# User Profileは、Domain内の個別ユーザーを表します。
#
# 概念:
# - Domain = プロジェクト/組織の枠組み
# - User Profile = その中の個人ユーザー
# - 各ユーザーは独立したホームディレクトリとワークスペースを持つ
#
# User Profileを作成することで:
# - ユーザー固有の設定が可能
# - ユーザーごとにアプリ（Code Editor等）を起動できる
# - ユーザーごとのリソース使用量を追跡できる
#
# 複数ユーザーの例:
# resource "aws_sagemaker_user_profile" "user_a" { ... }
# resource "aws_sagemaker_user_profile" "user_b" { ... }

resource "aws_sagemaker_user_profile" "main" {
  domain_id         = aws_sagemaker_domain.main.id
  user_profile_name = var.user_profile_name

  # ------------------------------------------------------------------------------
  # ユーザー固有設定
  # ------------------------------------------------------------------------------
  # Domainのデフォルト設定を上書きする場合に使用
  # 今回はDomainの設定をそのまま使用するため、省略可能
  #
  # user_settings {
  #   execution_role = aws_iam_role.user_specific_role.arn
  #
  #   # このユーザーだけ大きなインスタンスを使う場合
  #   code_editor_app_settings {
  #     default_resource_spec {
  #       instance_type = "ml.m5.xlarge"
  #     }
  #   }
  # }

  tags = {
    Name = "${var.project_name}-user-${var.user_profile_name}"
  }
}

# ==============================================================================
# SageMaker Space (Code Editor用のワークスペース)
# ==============================================================================
# なぜ必要？:
# Spaceは、Code EditorやJupyterLabアプリを実行するための「ワークスペース」です。
#
# 概念の階層:
# Domain (組織)
#   └── User Profile (ユーザー)
#        └── Space (ワークスペース)
#             └── Code Editor App (実際のアプリインスタンス)
#
# 重要なポイント:
# - Space作成時点ではインスタンスは起動しない
# - ユーザーがCode Editorを起動した時に、初めてEC2インスタンスが起動
# - Space削除してもユーザーデータ（EFS）は残る（User Profile削除まで）
# - 1つのSpaceには1つのAppTypeのみ指定可能（CodeEditorまたはJupyterLab）
#
# 複数のアプリを使いたい場合:
# Code Editor用とJupyterLab用に、それぞれ別のSpaceを作成する必要があります

resource "aws_sagemaker_space" "code_editor" {
  domain_id  = aws_sagemaker_domain.main.id
  space_name = "${var.user_profile_name}-code-editor-space"

  # このSpaceのオーナー（どのユーザーに紐付くか）
  ownership_settings {
    owner_user_profile_name = aws_sagemaker_user_profile.main.user_profile_name
  }

  # ------------------------------------------------------------------------------
  # Space固有の設定
  # ------------------------------------------------------------------------------
  # 重要: AppTypeは1つのみ指定可能
  # Code Editor専用のSpaceとして設定
  space_settings {
    # AppTypeを明示的に指定
    app_type = "CodeEditor"

    # Code Editorアプリの設定
    code_editor_app_settings {
      default_resource_spec {
        instance_type = var.sagemaker_instance_type
      }
    }
  }

  # Space共有設定（複数ユーザーで共有する場合）
  space_sharing_settings {
    sharing_type = "Private" # "Shared" にすると他のユーザーとワークスペースを共有可能
  }

  tags = {
    Name  = "${var.project_name}-code-editor-space"
    Owner = var.user_profile_name
  }
}

# ==============================================================================
# SageMaker Space (JupyterLab用のワークスペース) - オプション
# ==============================================================================
# JupyterLabも使いたい場合は、別のSpaceを作成します
# 今回は主にCode Editorを使用するため、コメントアウトしています
#
# resource "aws_sagemaker_space" "jupyter_lab" {
#   domain_id  = aws_sagemaker_domain.main.id
#   space_name = "${var.user_profile_name}-jupyter-lab-space"
#
#   ownership_settings {
#     owner_user_profile_name = aws_sagemaker_user_profile.main.user_profile_name
#   }
#
#   space_settings {
#     app_type = "JupyterLab"
#
#     jupyter_lab_app_settings {
#       default_resource_spec {
#         instance_type = var.sagemaker_instance_type
#       }
#     }
#   }
#
#   space_sharing_settings {
#     sharing_type = "Private"
#   }
#
#   tags = {
#     Name  = "${var.project_name}-jupyter-lab-space"
#     Owner = var.user_profile_name
#   }
# }
