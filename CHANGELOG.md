# Changelog

All notable changes to this action are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). The action versions independently of the rsigma engine; each release declares its minimum supported rsigma version.

## [Unreleased]

### Added

- Initial composite action `timescale/rsigma-action`: a one-step Detection-as-Code CI gate wrapping `rsigma rule lint`, `rule validate --resolve-sources`, a merge-base fields-drift diff, `rule backtest`, and `rule coverage`.
- Verified binary acquisition: downloads the `rsigma-<target>` release archive, checks it against `SHA256SUMS`, and verifies the SLSA build-provenance attestation with `gh attestation verify`, with per-version-and-target caching. No insecure fallback.
- PR annotations generated from the stable `rule lint --output-format json` envelope via workflow commands, carrying the lint rule name as the annotation title.
- A sticky PR summary comment (marker-based upsert) covering lint, validate, fields drift, the backtest expectations table, and ATT&CK coverage gaps, with links to the uploaded reports.
- JUnit XML and JSON backtest reports plus the ATT&CK Navigator layer uploaded as artifacts; action outputs for the resolved version, lint counts, backtest result, report paths, and fields-drift counts.
- Cross-platform support for the six rsigma release targets (Linux, macOS, Windows on amd64 and arm64).
- Golden tests for the annotation and comment renderers, a fixture rule set with corpus, expectations, and targets, and an ubuntu/macos/windows e2e workflow.
- Minimum supported rsigma version: `v0.17.0`.
