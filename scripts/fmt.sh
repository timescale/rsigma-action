#!/usr/bin/env bash
# Format step: run `rsigma rule fmt --check`, annotate files that are not in
# canonical format, and record the exit code for the gate.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

out="${RSIGMA_WORK}/fmt.out"
err="${RSIGMA_WORK}/fmt.err"

# `rule fmt` shipped in rsigma v0.27.0; an older pinned version skips the step
# instead of failing the gate on an unknown subcommand.
if ! rsigma rule fmt --help >/dev/null 2>&1; then
  echo "::notice title=rsigma fmt::the installed rsigma has no rule fmt command (needs v0.27.0 or later); skipping the format check"
  echo "unformatted=0" >>"${GITHUB_OUTPUT}"
  rsigma_record_status fmt 0
  printf 'skipped' >"${RSIGMA_WORK}/fmt.status"
  echo "rsigma-action: fmt skipped"
  exit 0
fi

rsigma rule fmt --check "${RSIGMA_RULES}" >"${out}" 2>"${err}"
rc=$?
cat "${out}" "${err}"

rsigma_record_status fmt "${rc}"
printf '%s' "${rc}" >"${RSIGMA_WORK}/fmt.status"

unformatted="$(rsigma_fmt_count "${out}")"
echo "unformatted=${unformatted}" >>"${GITHUB_OUTPUT}"

if [[ "${RSIGMA_ANNOTATIONS}" == "true" ]]; then
  rsigma_annotations_from_fmt "${out}"
fi

# Exit 2 means a file could not be read, parsed, or formatted, and 3 a flag
# conflict; neither is a formatting finding.
if [[ "${rc}" == "2" || "${rc}" == "3" ]]; then
  echo "::error title=rsigma fmt::format check could not run (exit ${rc}): a file could not be read, parsed, or formatted"
fi

echo "rsigma-action: fmt exit ${rc} (unformatted=${unformatted})"
exit 0
