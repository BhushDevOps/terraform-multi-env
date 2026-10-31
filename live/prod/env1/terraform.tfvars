# prod / env1 - production - India
env_name = "env1"

versioning_enabled        = true
force_destroy             = false
lifecycle_expiration_days = 365

# Shared EKS. Flip to true once live/<account>/02-eks has been applied.
# Gives this env: namespace <env_name> + IRSA role scoped to its own bucket.
eks_enabled = false
