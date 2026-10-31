# dev / env1 - shared team sandbox
env_name = "env1"

versioning_enabled        = false
force_destroy             = true
lifecycle_expiration_days = 0

# Shared EKS. Flip to true once live/<account>/02-eks has been applied.
# Gives this env: namespace <env_name> + IRSA role scoped to its own bucket.
eks_enabled = false
