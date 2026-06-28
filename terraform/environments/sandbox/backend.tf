terraform {
  backend "s3" {
    bucket         = "tf1-cdo05-tfstate-022267198114"
    key            = "sandbox/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf1-cdo05-tflock"
    encrypt        = true
  }
}
