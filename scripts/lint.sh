#!/usr/bin/env bash
# Lint step: run `rsigma rule lint` with the JSON envelope, turn findings into
# PR annotations, and record the exit code for the gate.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

out="${RSIGMA_WORK}/lint.json"

rsigma rule lint "${RSIGMA_RULES}" \
  --fail-level "${RSIGMA_FAIL_LEVEL}" \
  --output-format json >"${out}"
rc=$?
rsigma_record_status lint "${rc}"

errors=0
warnings=0
if [[ -s "${out}" ]] && jq -e . "${out}" >/dev/null 2>&1; then
  errors="$(jq -r '.summary.errors // 0' "${out}")"
  warnings="$(jq -r '.summary.warnings // 0' "${out}")"
fi
{
  echo "errors=${errors}"
  echo "warnings=${warnings}"
} >>"${GITHUB_OUTPUT}"

if [[ "${RSIGMA_ANNOTATIONS}" == "true" ]]; then
  rsigma_annotations_from_lint "${out}"
fi

# Rule/config errors (2/3) get a distinct fail-fast annotation so a broken
# ruleset is not read as a lint regression.
if [[ "${rc}" == "2" || "${rc}" == "3" ]]; then
  echo "::error title=rsigma lint::lint could not run (exit ${rc}): rule or config error"
fi

echo "rsigma-action: lint exit ${rc} (errors=${errors}, warnings=${warnings})"
exit 0
