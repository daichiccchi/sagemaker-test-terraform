terraform {
  backend "s3" {
    bucket         = "daichiccchi-terraform-state-bucket"
    key            = "sagemaker-code-editor/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    use_lockfile   = true      
  }
}