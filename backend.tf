terraform {
  backend "s3" {
    bucket         = "madgical-terraform-state-bucket"
    key            = "ncalifornia-scheduler/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    use_lockfile   = true
  }
}