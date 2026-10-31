# Values shared by EVERY environment inside the dev AWS account.
project       = "demoapp"
account_alias = "dev"
account_id    = "708485767572"
region        = "us-east-1"
owner         = "platform-team"

# State bucket for this account. stack/eks.tf reads 02-eks outputs from here.
state_bucket = "demo-app-tfstate-bk-dev-708485767572"
state_region = "ap-south-1"
