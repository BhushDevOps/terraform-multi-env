# Values shared by EVERY environment inside the prod AWS account.
project       = "demoapp"
account_alias = "prod"
account_id    = "333333333333"
region        = "ap-south-1"
owner         = "platform-team"

# State bucket for this account. stack/eks.tf reads 02-eks outputs from here.
state_bucket = "demoapp-tfstate-prod-333333333333"
state_region = "ap-south-1"
