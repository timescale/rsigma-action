#!/usr/bin/env bash
# Assert a format-check e2e run: the action outcome and the fmt-unformatted
# output must match the expected values. Consumed by .github/workflows/e2e.yml.
set -euo pipefail

fail=0

if [[ "${OUTCOME:-}" != "${EXPECTED_OUTCOME}" ]]; then
  echo "FAIL: expected outcome '${EXPECTED_OUTCOME}', got '${OUTCOME:-}'"
  fail=1
else
  echo "ok: outcome ${OUTCOME}"
fi

if [[ "${UNFORMATTED:-}" != "${EXPECTED_UNFORMATTED}" ]]; then
  echo "FAIL: expected fmt-unformatted=${EXPECTED_UNFORMATTED}, got '${UNFORMATTED:-}'"
  fail=1
else
  echo "ok: fmt-unformatted=${UNFORMATTED}"
fi

exit "${fail}"
