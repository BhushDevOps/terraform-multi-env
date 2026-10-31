# test / env2 - performance test
env_name = "env2"

versioning_enabled        = true
force_destroy             = true
lifecycle_expiration_days = 30

# Shared EKS. Flip to true once live/<account>/02-eks has been applied.
# Gives this env: namespace <env_name> + IRSA role scoped to its own bucket.
eks_enabled = false
