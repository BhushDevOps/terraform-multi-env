# One state BUCKET per AWS account, one state KEY per environment.
bucket         = "demo-app-tfstate-bk-dev-708485767572"
key            = "dev/env1/app/terraform.tfstate"
region         = "ap-south-1"
use_lockfile   = true
encrypt        = true
