#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "Check if there is any update for ctx7"
ctx7 upgrade

PLATFORMS=(claude codex)

# Phase 1: generate both platform variants in tmp and validate before touching the repo.
for platform in "${PLATFORMS[@]}"; do
  workdir="${TMP_DIR}/${platform}"
  mkdir -p "${workdir}"
  (cd "${workdir}" && ctx7 setup --cli "--${platform}" -y -p)

  case "${platform}" in
    claude) skill_src="${workdir}/.claude/skills/find-docs" ;;
    *)      skill_src="${workdir}/.agents/skills/find-docs" ;;
  esac

  if [[ ! -d "${skill_src}" ]]; then
    echo "Error: find-docs skill for ${platform} not found at ${skill_src}" >&2
    exit 1
  fi

  find "${skill_src}" -type f -exec sed -i '' 's/npx ctx7@latest/ctx7/g' {} +
done

CONTEXT7_RULE_SRC="${TMP_DIR}/claude/.claude/rules/context7.md"

if [[ ! -f "${CONTEXT7_RULE_SRC}" ]]; then
  echo "Error: context7 rule not found at ${CONTEXT7_RULE_SRC}" >&2
  exit 1
fi

sed -i '' 's/npx ctx7@latest/ctx7/g' "${CONTEXT7_RULE_SRC}"

# Phase 2: copy both platform variants into the repo.
for platform in "${PLATFORMS[@]}"; do
  case "${platform}" in
    claude) skill_src="${TMP_DIR}/${platform}/.claude/skills/find-docs" ;;
    *)      skill_src="${TMP_DIR}/${platform}/.agents/skills/find-docs" ;;
  esac

  dest="${REPO_ROOT}/skills/${platform}/find-docs"
  rm -rf "${dest}"
  cp -r "${skill_src}" "${dest}"
  echo "  find-docs (${platform}) -> skills/${platform}/find-docs"

  # ctx7 has no Cursor target, and Cursor reads Claude-shaped skills, so the
  # Cursor variant is the Claude one. Copied here rather than left to drift.
  if [[ "${platform}" == "claude" ]]; then
    cursor_dest="${REPO_ROOT}/skills/cursor/find-docs"
    rm -rf "${cursor_dest}"
    cp -r "${skill_src}" "${cursor_dest}"
    echo "  find-docs (cursor)  -> skills/cursor/find-docs"
  fi
done

AGENTS_MD="${REPO_ROOT}/instructions/AGENTS.md"

if grep -q '<!-- context7 -->' "${AGENTS_MD}"; then
  awk '
    /<!-- context7 -->/ {
      if (!in_block) { in_block=1; next }
      else { in_block=0; next }
    }
    { if (!in_block) print }
  ' "${AGENTS_MD}" > "${AGENTS_MD}.tmp" && mv "${AGENTS_MD}.tmp" "${AGENTS_MD}"
fi

printf '%s\n' "$(cat "${AGENTS_MD}")" > "${AGENTS_MD}"

rule_content="$(cat "${CONTEXT7_RULE_SRC}")"
{
  echo ""
  echo "<!-- context7 -->"
  echo "${rule_content}"
  echo "<!-- context7 -->"
} >> "${AGENTS_MD}"

echo "  context7 block -> instructions/AGENTS.md"
