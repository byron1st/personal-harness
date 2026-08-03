#!/usr/bin/env bash
# Extract a project's verification commands as JSON.
#
# Consumers: implement-dev, test-dev, fix-dev. Each of them otherwise rediscovers
# these by reading Makefile / AGENTS.md / CLAUDE.md / README.md with an LLM, every
# Worker, every round. This is a deterministic lookup, so it belongs in the shell.
#
# Usage: detect-commands.sh [repo-root]   (default: git toplevel, else cwd)
# Output: {"lint":…,"format":…,"test":…,"build":…,"mutation":…,"e2e":…,"source":…}
#         Each value is a command string, or null when nothing was found.
set -euo pipefail

root="${1:-}"
if [[ -z "${root}" ]]; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
cd "${root}"

# Makefile targets are the authoritative source when a Makefile exists: they are
# declared, not prose, so no guessing is involved.
makefile=""
for f in Makefile makefile GNUmakefile; do
  [[ -f "${f}" ]] && { makefile="${f}"; break; }
done

targets=""
if [[ -n "${makefile}" ]]; then
  # Real targets only: strip pattern rules, variable assignments, and .PHONY.
  targets="$(grep -Eo '^[a-zA-Z0-9_.-]+:' "${makefile}" | tr -d ':' | grep -v '^\.' | sort -u || true)"
fi

# First matching candidate wins; order encodes the usual naming preference.
pick_target() {
  local name
  for name in "$@"; do
    if printf '%s\n' "${targets}" | grep -qx "${name}"; then
      printf 'make %s' "${name}"
      return 0
    fi
  done
  return 1
}

lint="$(pick_target lint vet check golangci-lint || true)"
format="$(pick_target fmt format gofmt || true)"
test_cmd="$(pick_target test tests unit test-unit || true)"
build="$(pick_target build compile || true)"
mutation="$(pick_target test-mutation mutation mutate || true)"
e2e="$(pick_target test-e2e e2e || true)"

source_file="${makefile:-none}"

# Fall back to package.json scripts when there is no Makefile target. Anything
# beyond these two sources is prose, and prose is the caller's job to read — this
# script reports what it could not find rather than guessing at it.
if [[ -f package.json ]] && command -v jq >/dev/null 2>&1; then
  pick_script() {
    local name
    for name in "$@"; do
      if jq -e --arg n "${name}" '.scripts // {} | has($n)' package.json >/dev/null 2>&1; then
        printf 'npm run %s' "${name}"
        return 0
      fi
    done
    return 1
  }
  [[ -z "${lint}" ]] && lint="$(pick_script lint || true)"
  [[ -z "${format}" ]] && format="$(pick_script format fmt || true)"
  [[ -z "${test_cmd}" ]] && test_cmd="$(pick_script test || true)"
  [[ -z "${build}" ]] && build="$(pick_script build || true)"
  [[ -z "${mutation}" ]] && mutation="$(pick_script mutation test:mutation || true)"
  [[ -z "${e2e}" ]] && e2e="$(pick_script test:e2e e2e || true)"
  [[ "${source_file}" == "none" ]] && source_file="package.json" || source_file="${source_file}, package.json"
fi

emit() { [[ -z "$1" ]] && printf 'null' || printf '"%s"' "$1"; }

printf '{"lint":%s,"format":%s,"test":%s,"build":%s,"mutation":%s,"e2e":%s,"source":"%s"}\n' \
  "$(emit "${lint}")" "$(emit "${format}")" "$(emit "${test_cmd}")" \
  "$(emit "${build}")" "$(emit "${mutation}")" "$(emit "${e2e}")" "${source_file}"
