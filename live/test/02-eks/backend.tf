# Empty on purpose. The real values come from ./backend.hcl:
#   terraform -chdir=live/test/02-eks init -backend-config=backend.hcl
#
# Same state BUCKET as the env stacks, its own KEY: test/02-eks/terraform.tfstate
terraform {
  backend "s3" {}
}
