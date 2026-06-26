#!/usr/bin/env bash
# Point the floating major tag (e.g. v1) at the commit a release tag
# (e.g. v1.2.3) resolves to, via the GitHub refs API. Uses GH_TOKEN, so the
# checkout does not need persisted git credentials.
set -euo pipefail

tag="${EVENT_TAG:-}"
[[ -z "${tag}" ]] && tag="${INPUT_TAG:-}"
if [[ -z "${tag}" ]]; then
  echo "rsigma-action: no release tag provided" >&2
  exit 1
fi
if [[ ! "${tag}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
  echo "rsigma-action: tag '${tag}' is not vMAJOR.MINOR.PATCH" >&2
  exit 1
fi

major="${tag%%.*}" # v1.2.3 -> v1
repo="${GITHUB_REPOSITORY}"

# Resolve the commit the release tag points to (dereferencing an annotated tag).
object_sha="$(gh api "repos/${repo}/git/ref/tags/${tag}" --jq '.object.sha')"
object_type="$(gh api "repos/${repo}/git/ref/tags/${tag}" --jq '.object.type')"
if [[ "${object_type}" == "tag" ]]; then
  object_sha="$(gh api "repos/${repo}/git/tags/${object_sha}" --jq '.object.sha')"
fi

if gh api "repos/${repo}/git/ref/tags/${major}" >/dev/null 2>&1; then
  gh api --method PATCH "repos/${repo}/git/refs/tags/${major}" \
    -f sha="${object_sha}" -F force=true >/dev/null
  echo "rsigma-action: moved ${major} -> ${object_sha} (${tag})"
else
  gh api --method POST "repos/${repo}/git/refs" \
    -f ref="refs/tags/${major}" -f sha="${object_sha}" >/dev/null
  echo "rsigma-action: created ${major} -> ${object_sha} (${tag})"
fi
