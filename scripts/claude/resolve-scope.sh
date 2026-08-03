#!/usr/bin/env bash
# Resolve a review/test scope to JSON in one shot.
#
# Consumers: test-dev, review-code. Both otherwise re-derive the diff range,
# the changed-file absolute paths, and the languages involved through several
# Bash round trips plus LLM inference, once per round. All three are shell
# computations.
#
# Usage: resolve-scope.sh [branch|head|uncommitted|all] [repo-root]
#        default kind: branch (diff vs main/origin/main, incl. uncommitted)
# Output: {"kind":…,"range":…,"files":[…],"languages":[…],"file_count":N}
#         `files` are absolute paths. `range` is null for kinds without one.
set -euo pipefail

kind="${1:-branch}"
root="${2:-}"
if [[ -z "${root}" ]]; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
cd "${root}"

base=""
range="null"

case "${kind}" in
  branch)
    for cand in main origin/main master origin/master; do
      if git rev-parse --verify --quiet "${cand}" >/dev/null; then base="${cand}"; break; fi
    done
    current="$(git rev-parse --abbrev-ref HEAD)"
    # On the base branch itself only working-tree edits are in scope — there is
    # no branch to diff against, and diffing against itself yields nothing.
    if [[ -z "${base}" || "${current}" == "${base#origin/}" ]]; then
      files="$(git diff --name-only HEAD; git ls-files --others --exclude-standard)"
    else
      range="\"${base}...HEAD\""
      files="$(git diff --name-only "${base}...HEAD"; git diff --name-only HEAD; git ls-files --others --exclude-standard)"
    fi
    ;;
  head)
    range='"HEAD~1...HEAD"'
    files="$(git diff --name-only HEAD~1...HEAD)"
    ;;
  uncommitted)
    files="$(git diff --name-only HEAD; git ls-files --others --exclude-standard)"
    ;;
  all)
    files="$(git ls-files)"
    ;;
  *)
    echo "unknown scope kind: ${kind}" >&2
    exit 2
    ;;
esac

# Deleted files are in the diff but have no path to read; drop them so consumers
# never chase a missing file.
existing=""
while IFS= read -r f; do
  [[ -z "${f}" ]] && continue
  [[ -e "${f}" ]] && existing+="${f}"$'\n'
done <<< "$(printf '%s\n' "${files}" | sort -u)"

json_files=""
count=0
while IFS= read -r f; do
  [[ -z "${f}" ]] && continue
  [[ -n "${json_files}" ]] && json_files+=","
  json_files+="\"${root}/${f}\""
  count=$((count + 1))
done <<< "${existing}"

# Language detection exists so a Worker does not have to infer which convention
# files apply. Extensions decide it deterministically.
langs=""
add_lang() {
  case ",${langs}," in *",$1,"*) ;; *) [[ -n "${langs}" ]] && langs+=","; langs+="$1";; esac
}
while IFS= read -r f; do
  [[ -z "${f}" ]] && continue
  case "${f}" in
    *.go) add_lang go ;;
    *.swift) add_lang swift ;;
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs) add_lang ts ;;
    *.py) add_lang python ;;
    *.rs) add_lang rust ;;
    *.kt|*.kts) add_lang kotlin ;;
    *.java) add_lang java ;;
    *.rb) add_lang ruby ;;
    *.sh|*.bash) add_lang shell ;;
    *.md) add_lang markdown ;;
  esac
done <<< "${existing}"

json_langs=""
IFS=',' read -ra arr <<< "${langs}"
for l in "${arr[@]}"; do
  [[ -z "${l}" ]] && continue
  [[ -n "${json_langs}" ]] && json_langs+=","
  json_langs+="\"${l}\""
done

printf '{"kind":"%s","range":%s,"files":[%s],"languages":[%s],"file_count":%d}\n' \
  "${kind}" "${range}" "${json_files}" "${json_langs}" "${count}"
