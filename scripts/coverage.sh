#!/usr/bin/env bash
# Coverage step: map the ruleset onto ATT&CK, export a Navigator layer artifact,
# and capture the JSON report for the PR comment's gap section.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

nav="${RSIGMA_ARTIFACTS}/coverage-navigator.json"
report="${RSIGMA_WORK}/coverage.json"

args=(--rules "${RSIGMA_RULES}" --navigator "${nav}")

[[ -n "${RSIGMA_COVERAGE_TARGETS}" ]] && args+=(--targets "${RSIGMA_COVERAGE_TARGETS}")

# `true` selects the upstream default URL (bare flag); anything else is a
# path/URL value.
case "${RSIGMA_COVERAGE_BASELINE}" in
  "") ;;
  "true") args+=(--baseline) ;;
  *) args+=(--baseline "${RSIGMA_COVERAGE_BASELINE}") ;;
esac
case "${RSIGMA_COVERAGE_ATOMICS}" in
  "") ;;
  "true") args+=(--atomics) ;;
  *) args+=(--atomics "${RSIGMA_COVERAGE_ATOMICS}") ;;
esac

[[ "${RSIGMA_FAIL_ON_GAPS}" == "true" ]] && args+=(--fail-on-gaps)

rsigma rule coverage "${args[@]}" --output-format json >"${report}"
rc=$?
rsigma_record_status coverage "${rc}"

echo "navigator-path=${nav}" >>"${GITHUB_OUTPUT}"

if [[ "${rc}" == "2" || "${rc}" == "3" ]]; then
  echo "::error title=rsigma coverage::coverage could not run (exit ${rc}): rule or cross-reference error"
fi

echo "rsigma-action: coverage exit ${rc}"
exit 0
