#!/usr/bin/env bash
# Validate step: parse, compile, and resolve dynamic sources for the ruleset.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

args=("${RSIGMA_RULES}" --resolve-sources)

while IFS= read -r line; do
  [[ -n "${line}" ]] && args+=(-p "${line}")
done <<<"${RSIGMA_PIPELINES}"

while IFS= read -r line; do
  [[ -n "${line}" ]] && args+=(--source "${line}")
done <<<"${RSIGMA_SOURCES}"

out="${RSIGMA_WORK}/validate.txt"

rsigma rule validate "${args[@]}" >"${out}" 2>&1
rc=$?
cat "${out}"

rsigma_record_status validate "${rc}"
printf '%s' "${rc}" >"${RSIGMA_WORK}/validate.status"

if [[ "${rc}" != "0" && "${RSIGMA_ANNOTATIONS}" == "true" ]]; then
  echo "::error title=rsigma validate::validation failed (exit ${rc}) for ${RSIGMA_RULES}"
fi

echo "rsigma-action: validate exit ${rc}"
exit 0
