# One state BUCKET per AWS account, one state KEY per environment.
bucket         = "demoapp-tfstate-dev-111111111111"
key            = "dev/env3/app/terraform.tfstate"
region         = "ap-south-1"
dynamodb_table = "demoapp-tflock-dev"
encrypt        = true
