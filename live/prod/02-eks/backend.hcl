# Account-level layer: one state for the whole prod account, not one per env.
bucket       = "demoapp-tfstate-prod-333333333333"
key          = "prod/02-eks/terraform.tfstate"
region       = "ap-south-1"
use_lockfile = true
encrypt      = true
