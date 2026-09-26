# One state BUCKET per AWS account, one state KEY per environment.
bucket         = "demoapp-tfstate-prod-333333333333"
key            = "prod/env2/app/terraform.tfstate"
# NOTE: this is the STATE bucket region, not the resource region.
# Resources for this env live in eu-west-1, state still lives with the account.
region         = "ap-south-1"
dynamodb_table = "demoapp-tflock-prod"
encrypt        = true
