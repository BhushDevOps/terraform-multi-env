# Account-level layer: one state for the whole test account, not one per env.
bucket       = "demoapp-tfstate-test-222222222222"
key          = "test/02-eks/terraform.tfstate"
region       = "ap-south-1"
use_lockfile = true
encrypt      = true
