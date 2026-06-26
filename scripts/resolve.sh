#!/usr/bin/env bash
# Resolve the rsigma version and target triple, and lay out the work dirs.
# Runs before the cache step so the cache key pins a concrete version even when
# the consumer passed `latest`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

target="$(rsigma_target)"

version="${RSIGMA_VERSION_INPUT}"
if [[ "${version}" == "latest" ]]; then
  version="$(gh release view --repo "${RSIGMA_REPO}" --json tagName --jq .tagName)"
  if [[ -z "${version}" || "${version}" == "null" ]]; then
    echo "::error title=rsigma-action::could not resolve the latest rsigma release" >&2
    exit 1
  fi
fi

bin_dir="${RUNNER_TEMP}/rsigma-action/bin"
work="${RUNNER_TEMP}/rsigma-action/work"
artifacts="${work}/artifacts"
mkdir -p "${bin_dir}" "${artifacts}" "${work}/status"

{
  echo "version=${version}"
  echo "target=${target}"
} >>"${GITHUB_OUTPUT}"

{
  echo "RSIGMA_TARGET=${target}"
  echo "RSIGMA_BIN_DIR=${bin_dir}"
  echo "RSIGMA_WORK=${work}"
  echo "RSIGMA_ARTIFACTS=${artifacts}"
} >>"${GITHUB_ENV}"

echo "rsigma-action: resolved rsigma ${version} for ${target}"
