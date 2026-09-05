#!/usr/bin/env bash
# Ponytail (https://github.com/DietrichGebert/ponytail) install helpers.
# Sourced by apply-to-{claude,codex,cursor,grok}.sh.
# Each function prints one status line on stdout and always returns 0.

PONYTAIL_GITHUB="DietrichGebert/ponytail"
PONYTAIL_PLUGIN_ID="ponytail@ponytail"
PONYTAIL_CURSOR_MDC_URL="https://raw.githubusercontent.com/DietrichGebert/ponytail/main/.cursor/rules/ponytail.mdc"

install_ponytail_claude() {
  if ! command -v claude >/dev/null 2>&1; then
    echo "skipped (claude CLI not on PATH)"
    return 0
  fi

  local marketplaces add_out plugins inst_out
  marketplaces=$(claude plugin marketplace list --json 2>/dev/null || echo '[]')
  if ! printf '%s' "${marketplaces}" | rg -q 'DietrichGebert/ponytail'; then
    if ! add_out=$(claude plugin marketplace add "${PONYTAIL_GITHUB}" --scope user 2>&1); then
      echo "✗ marketplace add failed"
      printf '%s\n' "${add_out}" >&2
      return 0
    fi
  fi

  plugins=$(claude plugin list --json 2>/dev/null || echo '[]')
  if printf '%s' "${plugins}" | rg -q 'ponytail@ponytail'; then
    echo "✓ already installed"
    return 0
  fi

  if ! inst_out=$(claude plugin install "${PONYTAIL_PLUGIN_ID}" --scope user --yes 2>&1); then
    echo "✗ plugin install failed"
    printf '%s\n' "${inst_out}" >&2
    return 0
  fi
  echo "✓ installed"
}

install_ponytail_codex() {
  if ! command -v codex >/dev/null 2>&1; then
    echo "skipped (codex CLI not on PATH)"
    return 0
  fi

  local marketplaces add_out plugins inst_out
  marketplaces=$(codex plugin marketplace list 2>/dev/null || true)
  if ! printf '%s' "${marketplaces}" | rg -q 'ponytail'; then
    if ! add_out=$(codex plugin marketplace add "${PONYTAIL_GITHUB}" 2>&1); then
      echo "✗ marketplace add failed"
      printf '%s\n' "${add_out}" >&2
      return 0
    fi
  fi

  plugins=$(codex plugin list 2>/dev/null || true)
  if printf '%s' "${plugins}" | rg -q 'ponytail@ponytail[[:space:]]+installed'; then
    echo "✓ already installed"
    return 0
  fi

  if ! inst_out=$(codex plugin add "${PONYTAIL_PLUGIN_ID}" 2>&1); then
    echo "✗ plugin add failed"
    printf '%s\n' "${inst_out}" >&2
    return 0
  fi
  echo "✓ installed"
}

install_ponytail_cursor() {
  if ! command -v curl >/dev/null 2>&1; then
    echo "skipped (curl not on PATH)"
    return 0
  fi

  local dest="${HOME}/.cursor/rules/ponytail.mdc"
  local err
  mkdir -p "${HOME}/.cursor/rules"
  if ! err=$(curl -fsSL "${PONYTAIL_CURSOR_MDC_URL}" -o "${dest}" 2>&1); then
    echo "✗ download failed"
    printf '%s\n' "${err}" >&2
    return 0
  fi
  if [[ ! -s "${dest}" ]]; then
    echo "✗ download produced empty file"
    return 0
  fi
  echo "✓ installed ${dest}"
}

install_ponytail_grok() {
  if ! command -v grok >/dev/null 2>&1; then
    echo "skipped (grok CLI not on PATH)"
    return 0
  fi

  local list inst_out en_out
  list=$(grok plugin list --json 2>/dev/null || echo '[]')
  if ! printf '%s' "${list}" | rg -q 'ponytail'; then
    if ! inst_out=$(grok plugin install "${PONYTAIL_GITHUB}" --trust 2>&1); then
      echo "✗ plugin install failed"
      printf '%s\n' "${inst_out}" >&2
      return 0
    fi
  fi

  if ! en_out=$(grok plugin enable ponytail 2>&1); then
    echo "✗ installed but enable failed — add ponytail to [plugins].enabled in ~/.grok/config.toml"
    printf '%s\n' "${en_out}" >&2
    return 0
  fi
  echo "✓ installed and enabled"
}
