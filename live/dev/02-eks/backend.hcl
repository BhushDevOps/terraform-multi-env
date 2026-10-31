# Account-level layer: one state for the whole dev account, not one per env.
bucket       = "demo-app-tfstate-bk-dev-708485767572"
key          = "dev/02-eks/terraform.tfstate"
region       = "ap-south-1"
use_lockfile = true
encrypt      = true
