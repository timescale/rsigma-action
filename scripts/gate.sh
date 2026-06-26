#!/usr/bin/env bash
# Gate step: aggregate the per-step exit codes recorded in $RSIGMA_WORK/status
# and fail the action with the worst one. Running last (with `if: always()`)
# guarantees the PR comment and report artifacts publish before the gate fails.
set -uo pipefail

worst=0
status_dir="${RSIGMA_WORK:-}/status"

if [[ -d "${status_dir}" ]]; then
  for f in "${status_dir}"/*; do
    [[ -e "${f}" ]] || continue
    rc="$(cat "${f}")"
    name="$(basename "${f}")"
    if [[ "${rc}" != "0" ]]; then
      echo "rsigma-action: step '${name}' exited ${rc}"
      if ((rc > worst)); then
        worst="${rc}"
      fi
    fi
  done
fi

if [[ "${worst}" == "0" ]]; then
  echo "rsigma-action: all checks passed"
  exit 0
fi

# 1 = findings (lint/backtest/coverage gate); 2/3 = rule/config error.
echo "rsigma-action: failing the gate with exit ${worst}"
exit "${worst}"
