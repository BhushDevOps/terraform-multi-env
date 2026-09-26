# One state BUCKET per AWS account, one state KEY per environment.
bucket         = "demoapp-tfstate-prod-333333333333"
key            = "prod/env1/app/terraform.tfstate"
region         = "ap-south-1"
dynamodb_table = "demoapp-tflock-prod"
encrypt        = true
