#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "Check if there is any update for ctx7"
ctx7 upgrade

# Only the context7 rule is consumed; the find-docs skill ctx7 also emits is
# deliberately not vendored — instructions/AGENTS.md carries the same guidance.
WORKDIR="${TMP_DIR}/claude"
mkdir -p "${WORKDIR}"
(cd "${WORKDIR}" && ctx7 setup --cli --claude -y -p)

CONTEXT7_RULE_SRC="${WORKDIR}/.claude/rules/context7.md"

if [[ ! -f "${CONTEXT7_RULE_SRC}" ]]; then
  echo "Error: context7 rule not found at ${CONTEXT7_RULE_SRC}" >&2
  exit 1
fi

sed -i '' 's/npx ctx7@latest/ctx7/g' "${CONTEXT7_RULE_SRC}"

# ctx7 emits a bare `## Steps`, which lands as a top-level sibling of the
# harness's own H2 sections once the block is appended to AGENTS.md. Demote it
# so the steps stay visibly scoped to Context7.
sed -i '' 's/^## Steps$/### Context7 Steps/' "${CONTEXT7_RULE_SRC}"

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
