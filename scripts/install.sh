#!/usr/bin/env bash
# Download, verify, and install the rsigma binary, then add it to PATH.
#
# Verification is two-stage and has no insecure fallback: the SHA256SUMS
# manifest entry must match, and the SLSA build-provenance attestation must
# verify against timescale/rsigma. A cache hit skips download and verification
# but still re-exports PATH (PATH is not cached).
set -euo pipefail

ext="tar.gz"
bin="rsigma"
if [[ "${RUNNER_OS}" == "Windows" ]]; then
  ext="zip"
  bin="rsigma.exe"
fi

# PATH is per-job, never cached, so export it on every run.
echo "${RSIGMA_BIN_DIR}" >>"${GITHUB_PATH}"

if [[ -f "${RSIGMA_BIN_DIR}/${bin}" ]]; then
  echo "rsigma-action: using cached rsigma at ${RSIGMA_BIN_DIR}/${bin}"
  exit 0
fi

archive="rsigma-${RSIGMA_TARGET}.${ext}"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

echo "rsigma-action: downloading ${archive} from ${RSIGMA_REPO}@${RSIGMA_VERSION}"
gh release download "${RSIGMA_VERSION}" \
  --repo "${RSIGMA_REPO}" \
  --dir "${tmp}" \
  --pattern "${archive}" \
  --pattern "SHA256SUMS"

# 1. Checksum against the SHA256SUMS manifest. The manifest is generated with
#    `shasum -a 256 ./*`, so entries are prefixed with `./`.
expected="$(awk -v f="./${archive}" '$2 == f {print $1}' "${tmp}/SHA256SUMS" | head -n1)"
if [[ -z "${expected}" ]]; then
  expected="$(awk -v f="${archive}" '$2 == f {print $1}' "${tmp}/SHA256SUMS" | head -n1)"
fi
if [[ -z "${expected}" ]]; then
  echo "::error title=rsigma-action::no checksum for ${archive} in SHA256SUMS" >&2
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  actual="$(sha256sum "${tmp}/${archive}" | awk '{print $1}')"
else
  actual="$(shasum -a 256 "${tmp}/${archive}" | awk '{print $1}')"
fi

if [[ "${expected}" != "${actual}" ]]; then
  echo "::error title=rsigma-action::checksum mismatch for ${archive} (expected ${expected}, got ${actual})" >&2
  exit 1
fi
echo "rsigma-action: checksum verified"

# 2. SLSA build-provenance attestation. Hard failure on mismatch, by design.
gh attestation verify "${tmp}/${archive}" --repo "${RSIGMA_REPO}"
echo "rsigma-action: attestation verified"

if [[ "${ext}" == "zip" ]]; then
  unzip -o "${tmp}/${archive}" -d "${RSIGMA_BIN_DIR}" >/dev/null
else
  tar -xzf "${tmp}/${archive}" -C "${RSIGMA_BIN_DIR}"
fi
chmod +x "${RSIGMA_BIN_DIR}/${bin}" 2>/dev/null || true

echo "rsigma-action: installed $("${RSIGMA_BIN_DIR}/${bin}" --version 2>/dev/null || echo "${bin}")"
