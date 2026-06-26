#!/usr/bin/env bash
# Golden tests for the output-generating renderers (PR annotations and the
# sticky comment). They run the pure lib.sh functions over committed JSON
# report fixtures and diff the result against committed expected output, so
# formatting drift is a reviewed change rather than an accident. No rsigma
# binary or runner is needed.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "${REPO_ROOT}/scripts/lib.sh"

FIXTURE_WORK="${REPO_ROOT}/tests/golden/fixtures/work"
EXPECTED="${REPO_ROOT}/tests/golden/expected"
OUT="${REPO_ROOT}/tests/golden/.out"
mkdir -p "${OUT}"

# Deterministic environment for the renderers.
export RSIGMA_WORK="${FIXTURE_WORK}"
export RSIGMA_VERSION="v0.17.0"
export RUN_URL="https://github.com/timescale/rsigma-action/actions/runs/123"

rsigma_annotations_from_lint "${FIXTURE_WORK}/lint.json" >"${OUT}/annotations.txt"
rsigma_render_comment >"${OUT}/comment.md"

status=0
for name in annotations.txt comment.md; do
  if diff -u "${EXPECTED}/${name}" "${OUT}/${name}"; then
    echo "ok: ${name}"
  else
    echo "FAIL: ${name} differs from the golden (run tests/update-golden.sh to accept)"
    status=1
  fi
done

exit "${status}"
