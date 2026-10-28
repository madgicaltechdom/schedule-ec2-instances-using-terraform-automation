terraform {
  backend "s3" {
    bucket         = "madgical-terraform-state-bucket-ventech"
    key            = "ncalifornia-scheduler/terraform.tfstate"
    region         = "ap-south-1"
    profile        = "ventech"
    encrypt        = true
    use_lockfile   = true
  }
}