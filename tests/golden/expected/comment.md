<!-- rsigma-action -->
## RSigma Detection-as-Code

### Lint
- 1 error(s), 2 warning(s), 0 info(s) across 3 file(s); 1 failed.

| Severity | Rule | Location | Message |
|---|---|---|---|
| error | `missing_description` | rules/lint_warnings.yml:4 | rule has no description |
| warning | `missing_references` | rules/lint_warnings.yml | rule has no references |
| warning | `missing_date` | rules/lint_warnings.yml | rule has no date |

### Validate
- Rules parse, compile, and dynamic sources resolve.

### Fields drift (vs merge-base)
- 2 field(s) added, 1 field(s) removed.
  - Added: `CommandLine`, `OriginalFileName`
  - Removed: `LegacyField`

### Backtest
- 1/2 expectation(s) passed; 1 unexpected-firing rule(s) (1 fire(s)), policy `warn`.

| Rule | Bound | Actual | Result |
|---|---|---|---|
| PowerShell Encoded Command | >= 1 | 2 | pass |
| Suspicious Office Child Process | exactly 1 | 0 | **fail** |

Unexpected fires:
- `Renamed Net Utility`: 1 fire(s)

### ATT&CK coverage
- 3/3 rule(s) tagged; 4 technique(s), 1 tactic(s) covered.
  - Uncovered techniques: `T1003`

---
Reports: [run artifacts](https://github.com/timescale/rsigma-action/actions/runs/123) · rsigma `v0.17.0`
