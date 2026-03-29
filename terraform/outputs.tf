# ==============================================================================
# 出力値定義
# ==============================================================================
# Terraform実行後に表示される重要な情報

output "sagemaker_domain_id" {
  description = "SageMaker DomainのID"
  value       = aws_sagemaker_domain.main.id
}

output "sagemaker_domain_url" {
  description = "SageMaker DomainのURL"
  value       = aws_sagemaker_domain.main.url
}

output "user_profile_name" {
  description = "作成されたユーザープロファイル名"
  value       = aws_sagemaker_user_profile.main.user_profile_name
}

output "vpc_id" {
  description = "作成されたVPCのID"
  value       = aws_vpc.main.id
}

output "code_editor_access_url" {
  description = "Code Editorへのアクセス方法"
  value       = "AWS Console > SageMaker > Domains > ${aws_sagemaker_domain.main.id} > User profiles > ${aws_sagemaker_user_profile.main.user_profile_name} から Code Editor を起動してください"
}
