#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

(cd "${TMP_DIR}" && npx ctx7@latest setup --cli --claude -y -p)

FIND_DOCS_SRC="${TMP_DIR}/.claude/skills/find-docs"
CONTEXT7_RULE_SRC="${TMP_DIR}/.claude/rules/context7.md"

if [[ ! -d "${FIND_DOCS_SRC}" ]]; then
  echo "Error: find-docs skill not found at ${FIND_DOCS_SRC}" >&2
  exit 1
fi

if [[ ! -f "${CONTEXT7_RULE_SRC}" ]]; then
  echo "Error: context7 rule not found at ${CONTEXT7_RULE_SRC}" >&2
  exit 1
fi

for agent_dir in "${REPO_ROOT}"/skills/*/; do
  agent_name="$(basename "${agent_dir}")"
  dest="${agent_dir}find-docs"
  rm -rf "${dest}"
  cp -r "${FIND_DOCS_SRC}" "${dest}"
  echo "  find-docs -> skills/${agent_name}/find-docs"
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
