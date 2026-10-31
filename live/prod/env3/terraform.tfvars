# prod / env3 - disaster recovery
env_name = "env3"

versioning_enabled        = true
force_destroy             = false
lifecycle_expiration_days = 365

# Overrides the account default region. account.tfvars is loaded first,
# this file is loaded second, so this value wins. (disaster recovery, different region on purpose)
region = "ap-southeast-1"

# Shared EKS. Flip to true once live/<account>/02-eks has been applied.
# Gives this env: namespace <env_name> + IRSA role scoped to its own bucket.
eks_enabled = false
