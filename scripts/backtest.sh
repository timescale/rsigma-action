#!/usr/bin/env bash
# Backtest step: replay the corpus, diff per-rule fire counts against
# expectations, and emit JUnit XML + a JSON report as artifacts.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

report="${RSIGMA_ARTIFACTS}/backtest.json"
junit="${RSIGMA_ARTIFACTS}/backtest.xml"

args=(--rules "${RSIGMA_RULES}" --junit "${junit}" --report "${report}")

while IFS= read -r line; do
  [[ -n "${line}" ]] && args+=(--corpus "${line}")
done <<<"${RSIGMA_CORPUS}"

[[ -n "${RSIGMA_EXPECTATIONS}" ]] && args+=(--expectations "${RSIGMA_EXPECTATIONS}")
[[ -n "${RSIGMA_UNEXPECTED}" ]] && args+=(--unexpected "${RSIGMA_UNEXPECTED}")

while IFS= read -r line; do
  [[ -n "${line}" ]] && args+=(-p "${line}")
done <<<"${RSIGMA_PIPELINES}"

rsigma rule backtest "${args[@]}"
rc=$?
rsigma_record_status backtest "${rc}"

passed=false
[[ "${rc}" == "0" ]] && passed=true
{
  echo "passed=${passed}"
  echo "junit-path=${junit}"
  echo "report-path=${report}"
} >>"${GITHUB_OUTPUT}"

# Annotate each failed expectation on the expectations file.
if [[ "${RSIGMA_ANNOTATIONS}" == "true" && -s "${report}" ]] && jq -e . "${report}" >/dev/null 2>&1; then
  exp_file="${RSIGMA_EXPECTATIONS:-expectations}"
  jq -r --arg f "${exp_file}" '
    .expectations[]? | select(.pass == false)
    | "::error file=" + $f + ",title=backtest " + .rule
      + "::expected " + .bound + ", got " + (.actual | tostring)
  ' "${report}" || true
fi

if [[ "${rc}" == "2" || "${rc}" == "3" ]]; then
  echo "::error title=rsigma backtest::backtest could not run (exit ${rc}): rule or config error"
fi

echo "rsigma-action: backtest exit ${rc} (passed=${passed})"
exit 0
