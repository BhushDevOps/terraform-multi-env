# prod / env3 - disaster recovery
env_name = "env3"

versioning_enabled        = true
force_destroy             = false
lifecycle_expiration_days = 365

# Overrides the account default region. account.tfvars is loaded first,
# this file is loaded second, so this value wins. (disaster recovery, different region on purpose)
region = "ap-southeast-1"
