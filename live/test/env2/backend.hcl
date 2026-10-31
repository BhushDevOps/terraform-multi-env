# One state BUCKET per AWS account, one state KEY per environment.
bucket         = "demoapp-tfstate-test-222222222222"
key            = "test/env2/app/terraform.tfstate"
region         = "ap-south-1"
use_lockfile   = true
encrypt        = true
