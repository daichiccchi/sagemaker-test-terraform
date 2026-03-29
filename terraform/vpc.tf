# ==============================================================================
# VPC (Virtual Private Cloud) とネットワーク設定
# ==============================================================================
# なぜ必要？:
# SageMaker Domainは、セキュリティとネットワーク分離のためにVPC内で動作します。
# VPCは、AWSクラウド内の論理的に分離されたネットワーク空間です。

# ------------------------------------------------------------------------------
# VPC
# ------------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true # SageMakerがAWSサービスにアクセスするために必要
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ------------------------------------------------------------------------------
# インターネットゲートウェイ
# ------------------------------------------------------------------------------
# なぜ必要？:
# VPC内のリソースがインターネットと通信するための出入り口です。
# SageMaker Code Editorが外部のパッケージ（pip、npm等）をダウンロードする際に必要です。

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ------------------------------------------------------------------------------
# パブリックサブネット
# ------------------------------------------------------------------------------
# なぜ必要？:
# NATゲートウェイを配置し、プライベートサブネットからのインターネットアクセスを提供します。
# 複数のAZ（アベイラビリティゾーン）に配置することで、高可用性を実現します。

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
    Type = "Public"
  }
}

# ------------------------------------------------------------------------------
# プライベートサブネット
# ------------------------------------------------------------------------------
# なぜ必要？:
# SageMaker Domainは、セキュリティのためプライベートサブネットに配置します。
# プライベートサブネットは、インターネットから直接アクセスできない安全な領域です。
# 外部への通信はNATゲートウェイを経由します。

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
    Type = "Private"
  }
}

# ------------------------------------------------------------------------------
# Elastic IP (NATゲートウェイ用)
# ------------------------------------------------------------------------------
# なぜ必要？:
# NATゲートウェイは、固定のパブリックIPアドレスが必要です。

resource "aws_eip" "nat" {
  count = length(var.public_subnet_cidrs)

  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# ------------------------------------------------------------------------------
# NATゲートウェイ
# ------------------------------------------------------------------------------
# なぜ必要？:
# プライベートサブネット内のSageMakerが、インターネット上のリソース
# （PyPI、GitHub、AWS APIなど）にアクセスするために必要です。
# NATゲートウェイは、プライベートIPからパブリックIPへの変換を行います。

resource "aws_nat_gateway" "main" {
  count = length(var.public_subnet_cidrs)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.project_name}-nat-gateway-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# ------------------------------------------------------------------------------
# ルートテーブル: パブリックサブネット用
# ------------------------------------------------------------------------------
# なぜ必要？:
# パブリックサブネットからインターネットへのトラフィックを
# インターネットゲートウェイ経由でルーティングします。

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# パブリックサブネットとルートテーブルの関連付け
resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------------------------
# ルートテーブル: プライベートサブネット用
# ------------------------------------------------------------------------------
# なぜ必要？:
# プライベートサブネットからインターネットへのトラフィックを
# NATゲートウェイ経由でルーティングします。

resource "aws_route_table" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${var.project_name}-private-rt-${count.index + 1}"
  }
}

# プライベートサブネットとルートテーブルの関連付け
resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ------------------------------------------------------------------------------
# セキュリティグループ
# ------------------------------------------------------------------------------
# なぜ必要？:
# SageMaker Domainへのネットワークアクセスを制御するファイアウォールルールです。
# どのトラフィックを許可/拒否するかを定義します。

resource "aws_security_group" "sagemaker" {
  name        = "${var.project_name}-sg"
  description = "Security group for SageMaker Domain"
  vpc_id      = aws_vpc.main.id

  # アウトバウンド: すべての送信トラフィックを許可
  # なぜ必要？: SageMakerが外部サービス（S3、API、パッケージリポジトリ等）にアクセスするため
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  # インバウンド: VPC内部からの通信を許可
  # なぜ必要？: SageMaker Domain内の異なるコンポーネント間の通信のため
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow all traffic within security group"
  }

  # HTTPSインバウンド（VPC内のみ）
  # なぜ必要？: Code EditorのWeb UIへのアクセスのため
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow HTTPS from VPC"
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# ------------------------------------------------------------------------------
# VPCエンドポイント (オプション、コスト削減用)
# ------------------------------------------------------------------------------
# なぜ必要？:
# S3やSageMaker APIへのトラフィックをインターネット経由ではなく、
# AWS内部ネットワークを使用することで、NATゲートウェイのコストを削減し、
# 通信速度を向上させます。

# S3用VPCエンドポイント（ゲートウェイ型）
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"

  tags = {
    Name = "${var.project_name}-s3-endpoint"
  }
}

# S3エンドポイントとプライベートルートテーブルの関連付け
resource "aws_vpc_endpoint_route_table_association" "s3_private" {
  count = length(var.private_subnet_cidrs)

  route_table_id  = aws_route_table.private[count.index].id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

# SageMaker API用VPCエンドポイント（インターフェース型）
resource "aws_vpc_endpoint" "sagemaker_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.sagemaker.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.sagemaker.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-sagemaker-api-endpoint"
  }
}

# SageMaker Runtime用VPCエンドポイント
resource "aws_vpc_endpoint" "sagemaker_runtime" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.sagemaker.runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.sagemaker.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-sagemaker-runtime-endpoint"
  }
}
