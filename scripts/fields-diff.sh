#!/usr/bin/env bash
# Fields-drift step: diff the rule field set against the PR merge-base.
#
# `rule fields` has no native --diff, so the action computes it: run fields on
# HEAD, check the base commit out into a temporary worktree, run fields there,
# and diff the two field-name sets. Non-blocking by design (it records a 0 exit);
# the counts surface in the PR comment as coverage-drift signal.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

rsigma_record_status fields-diff 0

emit_zero() {
  {
    echo "added=0"
    echo "removed=0"
  } >>"${GITHUB_OUTPUT}"
  echo '{"added":[],"removed":[]}' >"${RSIGMA_WORK}/fields-diff.json"
}

if [[ -z "${BASE_SHA:-}" ]]; then
  echo "rsigma-action: no PR base sha; skipping fields drift"
  emit_zero
  exit 0
fi

# Diff against the actual merge-base of the PR head and its base branch, falling
# back to the base tip when the merge-base cannot be computed (shallow checkout).
base_ref="${BASE_SHA}"
merge_base="$(git merge-base "${BASE_SHA}" HEAD 2>/dev/null || true)"
[[ -n "${merge_base}" ]] && base_ref="${merge_base}"

pipe_args=()
while IFS= read -r line; do
  [[ -n "${line}" ]] && pipe_args+=(-p "${line}")
done <<<"${RSIGMA_PIPELINES}"

head_json="${RSIGMA_WORK}/fields-head.json"
# `${arr[@]+...}` keeps an empty array safe under `set -u` on bash 3.2 (macOS).
if ! rsigma rule fields --rules "${RSIGMA_RULES}" ${pipe_args[@]+"${pipe_args[@]}"} --output-format json >"${head_json}" 2>/dev/null; then
  echo "rsigma-action: head fields run failed; skipping fields drift"
  emit_zero
  exit 0
fi

base_json="${RSIGMA_WORK}/fields-base.json"
echo '{"fields":[]}' >"${base_json}"
wt="$(mktemp -d)"
if git worktree add --detach "${wt}" "${base_ref}" >/dev/null 2>&1; then
  (cd "${wt}" && rsigma rule fields --rules "${RSIGMA_RULES}" ${pipe_args[@]+"${pipe_args[@]}"} --output-format json) \
    >"${base_json}" 2>/dev/null || echo '{"fields":[]}' >"${base_json}"
  git worktree remove --force "${wt}" >/dev/null 2>&1 || true
else
  echo "rsigma-action: could not check out base ${base_ref}; treating all fields as added"
fi
rm -rf "${wt}" 2>/dev/null || true

jq -r '.fields[].field' "${head_json}" | sort -u >"${RSIGMA_WORK}/fields-head.txt"
jq -r '.fields[].field' "${base_json}" | sort -u >"${RSIGMA_WORK}/fields-base.txt"

comm -23 "${RSIGMA_WORK}/fields-head.txt" "${RSIGMA_WORK}/fields-base.txt" >"${RSIGMA_WORK}/fields-added.txt"
comm -13 "${RSIGMA_WORK}/fields-head.txt" "${RSIGMA_WORK}/fields-base.txt" >"${RSIGMA_WORK}/fields-removed.txt"

added_arr="$(jq -Rn '[inputs | select(length > 0)]' <"${RSIGMA_WORK}/fields-added.txt")"
removed_arr="$(jq -Rn '[inputs | select(length > 0)]' <"${RSIGMA_WORK}/fields-removed.txt")"
jq -n --argjson a "${added_arr}" --argjson r "${removed_arr}" '{added: $a, removed: $r}' \
  >"${RSIGMA_WORK}/fields-diff.json"

added="$(jq 'length' <<<"${added_arr}")"
removed="$(jq 'length' <<<"${removed_arr}")"
{
  echo "added=${added}"
  echo "removed=${removed}"
} >>"${GITHUB_OUTPUT}"

echo "rsigma-action: fields drift +${added} -${removed} (vs ${base_ref})"
exit 0
