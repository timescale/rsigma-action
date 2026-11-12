#!/usr/bin/env bash
# Shared helpers for the rsigma-action step scripts.
#
# The annotation and comment renderers are pure: they read JSON report files
# and write to stdout, so the golden tests can exercise them without a rsigma
# binary or a live runner.

# Map the runner OS/arch to the rsigma release target triple.
rsigma_target() {
  local os="${RUNNER_OS:-}" arch="${RUNNER_ARCH:-}"
  case "${os}/${arch}" in
    Linux/X64) echo "x86_64-unknown-linux-gnu" ;;
    Linux/ARM64) echo "aarch64-unknown-linux-gnu" ;;
    macOS/X64) echo "x86_64-apple-darwin" ;;
    macOS/ARM64) echo "aarch64-apple-darwin" ;;
    Windows/X64) echo "x86_64-pc-windows-msvc" ;;
    Windows/ARM64) echo "aarch64-pc-windows-msvc" ;;
    *)
      echo "rsigma-action: unsupported runner ${os}/${arch}" >&2
      return 1
      ;;
  esac
}

# Record a step's exit code so the final gate step can aggregate them. Steps
# never fail their own process (they exit 0); the gate decides the outcome so
# the PR comment and report artifacts always get a chance to publish.
rsigma_record_status() {
  local step="$1" rc="$2"
  mkdir -p "${RSIGMA_WORK}/status"
  printf '%s' "${rc}" >"${RSIGMA_WORK}/status/${step}"
}

# Emit a lint-style JSON envelope ({findings:[{path,severity,rule,message,line}]})
# as GitHub workflow-command annotations. Severities map error->error,
# warning->warning, info/hint->notice. The message is percent-escaped per the
# workflow-command rules; `line` is omitted when null.
rsigma_annotations_from_lint() {
  local file="$1"
  [[ -s "${file}" ]] || return 0
  jq -r '
    .findings[]?
    | (if .severity == "error" then "error"
       elif .severity == "warning" then "warning"
       else "notice" end) as $lvl
    | (.message | gsub("%"; "%25") | gsub("\r"; "%0D") | gsub("\n"; "%0A")) as $msg
    | "::" + $lvl + " file=" + .path
      + (if .line then ",line=" + (.line | tostring) else "" end)
      + ",title=" + .rule + "::" + $msg
  ' "${file}"
}

# Escape a workflow-command property value such as `file=`.
rsigma_escape_property() {
  local s="$1"
  s="${s//%/%25}"
  s="${s//$'\r'/%0D}"
  s="${s//$'\n'/%0A}"
  s="${s//:/%3A}"
  s="${s//,/%2C}"
  printf '%s' "${s}"
}

# Print the paths from the `Would reformat: <path>` lines of `rule fmt --check`.
rsigma_fmt_paths() {
  local file="$1" line
  [[ -s "${file}" ]] || return 0
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%$'\r'}"
    if [[ "${line}" == "Would reformat: "* ]]; then
      printf '%s\n' "${line#Would reformat: }"
    fi
  done <"${file}"
}

# Count the files `rule fmt --check` would reformat.
rsigma_fmt_count() {
  local n=0
  while IFS= read -r _; do
    n=$((n + 1))
  done < <(rsigma_fmt_paths "$1")
  echo "${n}"
}

# Emit one warning annotation per file `rule fmt --check` would reformat.
rsigma_annotations_from_fmt() {
  local path
  while IFS= read -r path; do
    echo "::warning file=$(rsigma_escape_property "${path}"),title=rsigma fmt::File is not in canonical format; run rsigma rule fmt --write"
  done < <(rsigma_fmt_paths "$1")
}

# Render the sticky PR comment markdown from the report files in $RSIGMA_WORK.
# Every section is conditional on its report file existing, so a run that only
# lints renders only the lint section. RSIGMA_VERSION and RUN_URL parameterize
# the footer (fixed in the golden tests for determinism).
rsigma_render_comment() {
  local work="${RSIGMA_WORK}"
  local lint="${work}/lint.json"
  local fields="${work}/fields-diff.json"
  local backtest="${work}/artifacts/backtest.json"
  local coverage="${work}/coverage.json"

  echo "<!-- rsigma-action -->"
  echo "## RSigma Detection-as-Code"
  echo ""

  if [[ -s "${lint}" ]] && jq -e . "${lint}" >/dev/null 2>&1; then
    echo "### Lint"
    jq -r '.summary
      | "- \(.errors) error(s), \(.warnings) warning(s), \(.infos) info(s) across \(.files_checked) file(s); \(.files_failed) failed."' "${lint}"
    local nf
    nf=$(jq '.findings | length' "${lint}")
    if [[ "${nf}" != "0" ]]; then
      echo ""
      echo "| Severity | Rule | Location | Message |"
      echo "|---|---|---|---|"
      jq -r '.findings[]
        | "| \(.severity) | `\(.rule)` | \(.path)\(if .line then ":" + (.line|tostring) else "" end) | \(.message) |"' "${lint}"
    fi
    echo ""
  fi

  if [[ -s "${work}/fmt.status" ]]; then
    local frc fn
    frc=$(cat "${work}/fmt.status")
    fn=$(rsigma_fmt_count "${work}/fmt.out")
    echo "### Format"
    case "${frc}" in
      0) echo "- All rule files are in canonical format." ;;
      1)
        echo "- ${fn} file(s) not in canonical format. Run \`rsigma rule fmt --write\` to rewrite them."
        rsigma_fmt_paths "${work}/fmt.out" | while IFS= read -r path; do
          echo "  - \`${path}\`"
        done
        ;;
      skipped) echo "- Skipped: the installed rsigma has no \`rule fmt\` command (needs v0.27.0 or later)." ;;
      *) echo "- The format check could not run (exit ${frc}). See the run log for the error." ;;
    esac
    echo ""
  fi

  if [[ -s "${work}/validate.status" ]]; then
    local vrc
    vrc=$(cat "${work}/validate.status")
    echo "### Validate"
    if [[ "${vrc}" == "0" ]]; then
      echo "- Rules parse, compile, and dynamic sources resolve."
    else
      echo "- Validation failed (exit ${vrc}). See the run log for the parser error."
    fi
    echo ""
  fi

  if [[ -s "${fields}" ]] && jq -e . "${fields}" >/dev/null 2>&1; then
    local added removed
    added=$(jq '.added | length' "${fields}")
    removed=$(jq '.removed | length' "${fields}")
    echo "### Fields drift (vs merge-base)"
    echo "- ${added} field(s) added, ${removed} field(s) removed."
    if [[ "${added}" != "0" ]]; then
      echo "  - Added: $(jq -r '.added | map("`" + . + "`") | join(", ")' "${fields}")"
    fi
    if [[ "${removed}" != "0" ]]; then
      echo "  - Removed: $(jq -r '.removed | map("`" + . + "`") | join(", ")' "${fields}")"
    fi
    echo ""
  fi

  if [[ -s "${backtest}" ]] && jq -e . "${backtest}" >/dev/null 2>&1; then
    echo "### Backtest"
    jq -r '.summary
      | "- \(.expectations_passed)/\(.expectations_total) expectation(s) passed; \(.unexpected_rules) unexpected-firing rule(s) (\(.unexpected_fires) fire(s)), policy `\(.unexpected_policy)`."' "${backtest}"
    local ne
    ne=$(jq '.expectations | length' "${backtest}")
    if [[ "${ne}" != "0" ]]; then
      echo ""
      echo "| Rule | Bound | Actual | Result |"
      echo "|---|---|---|---|"
      jq -r '.expectations[]
        | "| \(.rule) | \(.bound) | \(.actual) | \(if .pass then "pass" else "**fail**" end) |"' "${backtest}"
    fi
    local nu
    nu=$(jq '.unexpected | length' "${backtest}")
    if [[ "${nu}" != "0" ]]; then
      echo ""
      echo "Unexpected fires:"
      jq -r '.unexpected[] | "- `\(.rule_title)`: \(.fires) fire(s)"' "${backtest}"
    fi
    echo ""
  fi

  if [[ -s "${coverage}" ]] && jq -e . "${coverage}" >/dev/null 2>&1; then
    echo "### ATT&CK coverage"
    jq -r '.summary
      | "- \(.rules_tagged)/\(.rules_total) rule(s) tagged; \(.techniques) technique(s), \(.tactics) tactic(s) covered."' "${coverage}"
    local uncovered
    uncovered=$(jq -r '(.targets.uncovered // [])
      + (.baseline.baseline_not_covered // [])
      + (.atomics.atomics_without_rule // [])
      | unique | length' "${coverage}")
    if [[ "${uncovered}" != "0" ]]; then
      echo "  - Uncovered techniques: $(jq -r '((.targets.uncovered // []) + (.baseline.baseline_not_covered // []) + (.atomics.atomics_without_rule // [])) | unique | map("`" + . + "`") | join(", ")' "${coverage}")"
    fi
    echo ""
  fi

  echo "---"
  echo "Reports: [run artifacts](${RUN_URL:-#}) · rsigma \`${RSIGMA_VERSION:-unknown}\`"
}
