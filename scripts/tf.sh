#!/usr/bin/env bash
# tf.sh - run Terraform for one environment inside one AWS account.
#
# Usage:
#   ./scripts/tf.sh dev  env1 plan
#   ./scripts/tf.sh dev  env1 apply
#   ./scripts/tf.sh prod env2 plan
#
# See scripts/tf.ps1 for the explanation of why TF_DATA_DIR is set per
# environment. Short version: without it, env1 and env2 would share one
# .terraform folder and you could apply env1's plan onto env2's state.

set -euo pipefail

ACCOUNT="${1:-}"
ENVIRONMENT="${2:-}"
ACTION="${3:-plan}"

if [[ -z "$ACCOUNT" || -z "$ENVIRONMENT" ]]; then
  echo "usage: $0 <dev|test|prod> <env1|env2|env3> <init|validate|plan|apply|destroy|output|fmt>" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK_DIR="$REPO_ROOT/live/$ACCOUNT/stack"
ENV_DIR="$REPO_ROOT/live/$ACCOUNT/$ENVIRONMENT"

[[ -d "$ENV_DIR" ]] || { echo "No such environment: live/$ACCOUNT/$ENVIRONMENT" >&2; exit 1; }

# Relative to STACK_DIR, because terraform -chdir moves there.
BACKEND_CFG="../$ENVIRONMENT/backend.hcl"
ACCOUNT_VARS="../account.tfvars"
ENV_VARS="../$ENVIRONMENT/terraform.tfvars"
PLAN_FILE="../$ENVIRONMENT/tfplan"

export TF_DATA_DIR="../$ENVIRONMENT/.terraform"

tf_init() {
  echo "==> init  $ACCOUNT/$ENVIRONMENT"
  terraform -chdir="$STACK_DIR" init -reconfigure -backend-config="$BACKEND_CFG"
}

case "$ACTION" in
  fmt)      terraform -chdir="$REPO_ROOT" fmt -recursive ;;
  init)     tf_init ;;
  validate) tf_init; terraform -chdir="$STACK_DIR" validate ;;
  plan)
    tf_init
    echo "==> plan  $ACCOUNT/$ENVIRONMENT"
    terraform -chdir="$STACK_DIR" plan \
      -var-file="$ACCOUNT_VARS" -var-file="$ENV_VARS" -out="$PLAN_FILE"
    ;;
  apply)
    [[ -f "$ENV_DIR/tfplan" ]] || { echo "No saved plan. Run plan first." >&2; exit 1; }
    echo "==> apply $ACCOUNT/$ENVIRONMENT"
    terraform -chdir="$STACK_DIR" apply "$PLAN_FILE"
    ;;
  destroy)
    tf_init
    echo "==> DESTROY $ACCOUNT/$ENVIRONMENT"
    terraform -chdir="$STACK_DIR" destroy \
      -var-file="$ACCOUNT_VARS" -var-file="$ENV_VARS"
    ;;
  output)   terraform -chdir="$STACK_DIR" output ;;
  *)        echo "unknown action: $ACTION" >&2; exit 1 ;;
esac
