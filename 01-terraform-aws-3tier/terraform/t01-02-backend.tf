terraform {
  # Adding Backend as S3 for Remote State Storage
  backend "s3" {
    bucket = "devops-projects-infra-test"
    key    = "dev/devops-01/terraform.tfstate"
    region = "us-east-1"

    # For State Locking
    dynamodb_table = "dev-devops-01"
  }
}
