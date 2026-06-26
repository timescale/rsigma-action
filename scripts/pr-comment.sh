#!/usr/bin/env bash
# Render the sticky PR comment and upsert it via the GitHub API. One comment per
# PR carries the `<!-- rsigma-action -->` marker; re-runs edit it in place. A
# failed post warns but never fails the gate (the reports still upload).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

body_file="${RSIGMA_WORK}/comment.md"
rsigma_render_comment >"${body_file}"

# Build the request body as JSON so the markdown is escaped correctly, rather
# than relying on field-coercion of a raw string.
payload="${RSIGMA_WORK}/comment-payload.json"
jq -n --rawfile body "${body_file}" '{body: $body}' >"${payload}"

existing="$(gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" --paginate \
  --jq '.[] | select(.body | startswith("<!-- rsigma-action -->")) | .id' 2>/dev/null | head -n1 || true)"

if [[ -n "${existing}" ]]; then
  if gh api --method PATCH "repos/${REPO}/issues/comments/${existing}" --input "${payload}" >/dev/null 2>&1; then
    echo "rsigma-action: updated PR comment ${existing}"
  else
    echo "::warning title=rsigma-action::could not update the PR comment (need pull-requests: write?)"
  fi
else
  if gh api --method POST "repos/${REPO}/issues/${PR_NUMBER}/comments" --input "${payload}" >/dev/null 2>&1; then
    echo "rsigma-action: posted PR comment"
  else
    echo "::warning title=rsigma-action::could not post the PR comment (need pull-requests: write?)"
  fi
fi

exit 0
