#!/usr/bin/env bash
# Assert the green-path e2e produced the expected outputs and report artifacts,
# independent of the gate's pass/fail (lint severities can vary by rsigma
# version). Consumed by .github/workflows/e2e.yml.
set -euo pipefail

fail=0

if [[ -z "${RSIGMA_VERSION:-}" ]]; then
  echo "FAIL: rsigma-version output is empty"
  fail=1
else
  echo "ok: ran rsigma ${RSIGMA_VERSION}"
fi

if [[ "${BACKTEST_PASSED:-}" != "true" ]]; then
  echo "FAIL: expected backtest-passed=true, got '${BACKTEST_PASSED:-}'"
  fail=1
else
  echo "ok: backtest passed"
fi

if [[ -z "${REPORT_PATH:-}" || ! -s "${REPORT_PATH}" ]]; then
  echo "FAIL: backtest report missing at '${REPORT_PATH:-}'"
  fail=1
else
  echo "ok: backtest report at ${REPORT_PATH}"
fi

if [[ -z "${NAVIGATOR_PATH:-}" || ! -s "${NAVIGATOR_PATH}" ]]; then
  echo "FAIL: navigator layer missing at '${NAVIGATOR_PATH:-}'"
  fail=1
else
  echo "ok: navigator layer at ${NAVIGATOR_PATH}"
fi

exit "${fail}"
