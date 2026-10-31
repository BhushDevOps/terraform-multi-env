# Values shared by EVERY environment inside the test AWS account.
project       = "demoapp"
account_alias = "test"
account_id    = "222222222222"
region        = "ap-south-1"
owner         = "platform-team"

# State bucket for this account. stack/eks.tf reads 02-eks outputs from here.
state_bucket = "demoapp-tfstate-test-222222222222"
state_region = "ap-south-1"
