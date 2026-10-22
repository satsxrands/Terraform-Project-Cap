#!/usr/bin/env bash
#
# Run Terraform against exactly one environment.
#
# Passes the matching backend config and values file together, so a dev
# configuration can never be paired with prd state. Each environment also
# gets its own .terraform directory (TF_DATA_DIR), so switching environment
# never reuses another environment's backend initialisation.
#
# Usage:
#   ./scripts/tf.sh <dev|qa|prd> <init|plan|apply|destroy|output> [extra terraform args]
#
# Examples:
#   ./scripts/tf.sh dev plan
#   ./scripts/tf.sh qa apply
#   ./scripts/tf.sh prd destroy

set -euo pipefail

ENVIRONMENT="${1:-}"
ACTION="${2:-}"
shift 2 || true

case "$ENVIRONMENT" in
  dev|qa|prd) ;;
  *) echo "Usage: $0 <dev|qa|prd> <init|plan|apply|destroy|output> [args]" >&2; exit 1 ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="${ROOT}/envs/${ENVIRONMENT}"
BACKEND="${ENV_DIR}/${ENVIRONMENT}.tfbackend"
VARS="${ENV_DIR}/${ENVIRONMENT}.tfvars"

for f in "$BACKEND" "$VARS"; do
  [[ -f "$f" ]] || { echo "ERROR: missing $f" >&2; exit 1; }
done

cd "$ROOT"
export TF_DATA_DIR="${ROOT}/.terraform-${ENVIRONMENT}"

echo ">> environment: ${ENVIRONMENT}  (state: $(grep '^key' "$BACKEND" | cut -d'"' -f2))"

# Initialise on first use for this environment, or on explicit request.
if [[ "$ACTION" == "init" || ! -d "$TF_DATA_DIR" ]]; then
  terraform init -reconfigure -backend-config="$BACKEND"
  [[ "$ACTION" == "init" ]] && exit 0
fi

case "$ACTION" in
  plan|apply|destroy)
    terraform "$ACTION" -var-file="$VARS" "$@"
    ;;
  output)
    terraform output "$@"
    ;;
  *)
    echo "ERROR: unknown action '${ACTION}'. Use init, plan, apply, destroy or output." >&2
    exit 1
    ;;
esac
