# rsigma-action

GitHub Action for Detection-as-Code (DaC) powered by [RSigma](https://github.com/timescale/rsigma): lint, validate, fields-drift, backtest, and ATT&CK coverage in one CI gate.

This composite action turns a Sigma rule repository into a pull-request gate. It installs a verified rsigma release, runs the detection-as-code checks, annotates findings on the diff, keeps a single sticky summary comment up to date, and uploads the backtest and ATT&CK Navigator reports as artifacts.

## Quick start

```yaml
name: Detection-as-Code
on:
  pull_request:
permissions:
  contents: read
  pull-requests: write # the sticky summary comment
jobs:
  rsigma:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0 # required for the merge-base fields-drift diff
      - uses: timescale/rsigma-action@v1
        with:
          rules: rules/
```

The minimal run lints, validates, and diffs rule fields. Set `corpus` to add backtesting and `coverage: "true"` to add ATT&CK coverage.

## Full example

```yaml
- uses: timescale/rsigma-action@v1
  with:
    version: v0.17.0 # pin a release; the default `latest` resolves once then caches
    rules: rules/
    pipelines: |
      ecs_windows
    lint-fail-level: warning
    sources: |
      sources/threat-intel.yml
    corpus: tests/corpus
    expectations: tests/expectations.yml
    unexpected: fail
    coverage: "true"
    coverage-atomics: "true" # `true` uses the upstream Atomic Red Team index
    coverage-baseline: "true" # `true` uses the SigmaHQ baseline heatmap
    coverage-targets: tests/targets.txt
    fail-on-gaps: "true"
```

## What it runs

The action wraps shipped rsigma subcommands. Each step is independent and gated by an input toggle; a non-zero rsigma exit is recorded and surfaced by a final gate step, so the comment and artifacts always publish before the run fails.

1. Lint: `rsigma rule lint <rules> --fail-level <level> --output-format json`. Findings become PR annotations generated from the stable JSON envelope (not text-scraping problem matchers), so each annotation carries the lint rule name as its title.
2. Validate: `rsigma rule validate <rules> --resolve-sources [--source ...] [-p ...]`. Proves rules parse, compile, and that dynamic source references resolve.
3. Fields drift: `rule fields` has no native diff, so the action runs it on HEAD and on the PR merge-base (in a temporary git worktree) and diffs the field-name sets. Non-blocking; it surfaces coverage drift in the comment. Runs on pull requests only.
4. Backtest: `rsigma rule backtest --rules <rules> --corpus <corpus> [--expectations ...] [--unexpected ...] [-p ...] --junit backtest.xml --report backtest.json`. Runs only when `corpus` is set. The JUnit XML and JSON report upload as artifacts.
5. Coverage: `rsigma rule coverage --rules <rules> --navigator layer.json [--targets ...] [--baseline ...] [--atomics ...] [--fail-on-gaps]`. The Navigator layer (format 4.5) uploads as an artifact, ready to load into the [ATT&CK Navigator](https://mitre-attack.github.io/attack-navigator/).

Exit codes follow the rsigma house scheme: `1` is findings (fails the gate), `2` is a rule error, and `3` is a config error. A `2`/`3` gets a distinct fail-fast annotation, so a broken expectations or rule file is never reported as a rule regression.

## Inputs

| Input | Default | Description |
|---|---|---|
| `version` | `latest` | rsigma release to install (e.g. `v0.17.0`). `latest` resolves the newest release once, then pins it for the cache key. Pinning a tag is recommended. |
| `rules` | `rules/` | Rule file or directory, passed to every step. |
| `pipelines` | unset | Pipeline names or paths (one per line), forwarded as repeated `-p`. |
| `working-directory` | `.` | Repo-relative root for all paths. |
| `lint` | `true` | Run the lint step. |
| `validate` | `true` | Run the validate step. |
| `fields-diff` | `true` | Run the merge-base fields-drift diff (pull requests only). |
| `lint-fail-level` | `warning` | Forwarded to `rule lint --fail-level` (`error`/`warning`/`info`). The rsigma default is `error`; this action is deliberately stricter. |
| `sources` | unset | Dynamic-source files or directories (one per line) for `--resolve-sources --source`. |
| `corpus` | unset | Backtest corpus file or directory (one per line). The backtest step runs only when set. |
| `expectations` | unset | Expectations YAML, forwarded to `rule backtest --expectations`. |
| `unexpected` | `warn` | Forwarded to `rule backtest --unexpected` (`fail`/`warn`/`ignore`). |
| `coverage` | `false` | Run the ATT&CK coverage step. |
| `coverage-targets` | unset | Target technique list, forwarded to `rule coverage --targets`. |
| `coverage-baseline` | unset | Baseline Navigator layer. `true` selects the upstream SigmaHQ default; otherwise a path or URL. |
| `coverage-atomics` | unset | Atomic Red Team index. `true` selects the upstream default; otherwise a path, URL, or `atomics/` directory. |
| `fail-on-gaps` | `false` | Forwarded to `rule coverage --fail-on-gaps`. |
| `annotations` | `true` | Emit workflow-command annotations on the PR diff. |
| `pr-comment` | `true` | Maintain the sticky summary comment on pull requests. |
| `github-token` | `${{ github.token }}` | Token used to download the release, verify its attestation, and upsert the comment. |

## Outputs

| Output | Description |
|---|---|
| `rsigma-version` | The resolved rsigma version that ran. |
| `lint-errors` | Lint error count from the JSON envelope summary. |
| `lint-warnings` | Lint warning count from the JSON envelope summary. |
| `backtest-passed` | `true` when the backtest ran and all expectations passed, `false` otherwise. |
| `junit-path` | Path to the backtest JUnit XML report, if produced. |
| `report-path` | Path to the backtest JSON report, if produced. |
| `navigator-path` | Path to the coverage ATT&CK Navigator layer, if produced. |
| `fields-added` | Number of rule fields added relative to the merge-base. |
| `fields-removed` | Number of rule fields removed relative to the merge-base. |

## Permissions

The action needs `contents: read` to check out the rules and download the public rsigma release. The sticky PR comment additionally needs `pull-requests: write`. If you do not want the comment, set `pr-comment: "false"` and `contents: read` is enough.

```yaml
permissions:
  contents: read
  pull-requests: write
```

## Binary verification

The install step downloads the `rsigma-<target>` archive from the [timescale/rsigma releases](https://github.com/timescale/rsigma/releases) and verifies it twice before putting it on `PATH`: the `SHA256SUMS` manifest entry must match, and the SLSA build-provenance attestation must verify against `timescale/rsigma` with `gh attestation verify`. There is no insecure fallback. The unpacked binary is cached per version and target, so steady-state runs skip the download and verification.

## Requirements

- The fields-drift diff needs git history for the merge-base, so check out with `fetch-depth: 0`.
- The action supports the six rsigma release targets: Linux, macOS, and Windows on amd64 and arm64.
- Minimum rsigma version: `v0.17.0` (the release where `rule backtest` and `rule coverage` shipped). Older versions work for lint, validate, and fields-drift only.

## Pinning

For hardened consumers, pin the action by full commit SHA:

```yaml
- uses: timescale/rsigma-action@<full-sha> # v1.0.0
```

The floating `v1` major tag is moved to each `v1.x.y` release. The `version` input that selects the rsigma engine is independent of the action version, and pinning a concrete `version` (rather than `latest`) keeps runs reproducible.

## Development

- `bash tests/run-golden.sh` runs the golden tests for the annotation and comment renderers (pure functions over JSON fixtures, no rsigma binary needed). Regenerate with `bash tests/update-golden.sh` after an intentional formatting change.
- `shellcheck -x scripts/*.sh tests/*.sh` must pass.
- `.github/workflows/e2e.yml` runs the action against `fixtures/` on the ubuntu/macos/windows matrix.
- `zizmor --pedantic` must pass on the workflows and `action.yml`.

## License

MIT. See [LICENSE](LICENSE).
