# prod / env2 - production - Europe
env_name = "env2"

versioning_enabled        = true
force_destroy             = false
lifecycle_expiration_days = 365

# Overrides the account default region. account.tfvars is loaded first,
# this file is loaded second, so this value wins. (serves European customers)
region = "eu-west-1"

# Shared EKS. Flip to true once live/<account>/02-eks has been applied.
# Gives this env: namespace <env_name> + IRSA role scoped to its own bucket.
eks_enabled = false
