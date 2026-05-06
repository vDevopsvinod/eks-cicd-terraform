terraform {
  backend "s3" {
    bucket = "vinod-terraform-states-001"
    key    = "eks/terraform.tfstate"
    region = "us-east-1"
  }
}