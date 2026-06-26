#!/usr/bin/env bash
# Regenerate the committed golden output from the current renderers and
# fixtures. Run this after an intentional formatting change, then review the
# diff before committing.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "${REPO_ROOT}/scripts/lib.sh"

FIXTURE_WORK="${REPO_ROOT}/tests/golden/fixtures/work"
EXPECTED="${REPO_ROOT}/tests/golden/expected"
mkdir -p "${EXPECTED}"

export RSIGMA_WORK="${FIXTURE_WORK}"
export RSIGMA_VERSION="v0.17.0"
export RUN_URL="https://github.com/timescale/rsigma-action/actions/runs/123"

rsigma_annotations_from_lint "${FIXTURE_WORK}/lint.json" >"${EXPECTED}/annotations.txt"
rsigma_render_comment >"${EXPECTED}/comment.md"

echo "rsigma-action: regenerated goldens in ${EXPECTED}"
