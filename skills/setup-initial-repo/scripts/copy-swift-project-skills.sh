#!/usr/bin/env bash
# Copy SwiftUI / macOS Agent Skills from the local external-skills tree
# into a target repo's .agents/skills.
#
# These trees are third-party (Paul Hudson MIT skills + Apple Xcode 27
# skills) and are not vendored into personal-harness. setup-initial-repo
# copies them at bootstrap so they travel with the new project.
#
# Consumer: setup-initial-repo, Swift / macOS projects only.
#
# Usage: copy-swift-project-skills.sh [dest-root] [source-root]
#   dest-root    default: cwd
#   source-root  default: $SWIFT_SKILLS_SOURCE, else a sibling directory
#                named external-skills of any ancestor of dest-root
#
# Prints the copied skill names, one per line, then a summary line.
set -euo pipefail

SOURCE_DIRNAME="external-skills"
XCODE27_BUNDLE="xcode27-skills"
XCODE27_SKILLS=(swiftui-specialist swiftui-whats-new-27)

dest_root="${1:-}"
if [[ -z "${dest_root}" ]]; then
  dest_root="$(pwd)"
fi
dest_root="$(cd "${dest_root}" && pwd)"
dest_skills="${dest_root}/.agents/skills"

resolve_source_root() {
  local explicit="${1:-}"
  if [[ -n "${explicit}" ]]; then
    printf '%s\n' "${explicit}"
    return 0
  fi
  if [[ -n "${SWIFT_SKILLS_SOURCE:-}" ]]; then
    printf '%s\n' "${SWIFT_SKILLS_SOURCE}"
    return 0
  fi
  local dir="${dest_root}"
  while [[ "${dir}" != "/" ]]; do
    local parent
    parent="$(dirname "${dir}")"
    if [[ -d "${parent}/${SOURCE_DIRNAME}" ]]; then
      printf '%s\n' "${parent}/${SOURCE_DIRNAME}"
      return 0
    fi
    dir="${parent}"
  done
  return 1
}

copy_skill_dir() {
  local src="$1"
  local name
  name="$(basename "${src}")"
  local target="${dest_skills}/${name}"
  if [[ ! -f "${src}/SKILL.md" ]]; then
    echo "error: not a skill directory (missing SKILL.md): ${src}" >&2
    return 1
  fi
  rm -rf "${target}"
  mkdir -p "${target}"
  cp -R "${src}/." "${target}/"
  # Drop upstream packaging, not the skill body: git metadata, Claude
  # marketplace plugin, and the nested npx `skills/` wrapper (relative
  # symlinks that would break once copied).
  rm -rf "${target}/.git" "${target}/.claude-plugin" "${target}/skills"
  printf '%s\n' "${name}"
}

source_root="${2:-}"
if ! source_root="$(resolve_source_root "${source_root}")"; then
  echo "error: could not find ${SOURCE_DIRNAME} source tree" >&2
  echo "looked for \$SWIFT_SKILLS_SOURCE and a sibling named ${SOURCE_DIRNAME} of any ancestor of ${dest_root}" >&2
  echo "re-run: copy-swift-project-skills.sh <dest-root> <source-root>" >&2
  exit 1
fi
source_root="$(cd "${source_root}" && pwd)"

if [[ ! -d "${source_root}" ]]; then
  echo "error: source root is not a directory: ${source_root}" >&2
  exit 1
fi

shopt -s nullglob

mkdir -p "${dest_skills}"

copied=()
xcode_bundle=""

for bundle in "${source_root}"/*/; do
  bundle_name="$(basename "${bundle%/}")"
  if [[ "${bundle_name}" == "${XCODE27_BUNDLE}" ]]; then
    xcode_bundle="${bundle%/}"
    continue
  fi
  for skill_md in "${bundle}"*/SKILL.md; do
    [[ -f "${skill_md}" ]] || continue
    copied+=("$(copy_skill_dir "$(dirname "${skill_md}")")")
  done
done

if [[ -z "${xcode_bundle}" ]]; then
  echo "error: missing ${XCODE27_BUNDLE} under ${source_root}" >&2
  exit 1
fi

for name in "${XCODE27_SKILLS[@]}"; do
  src="${xcode_bundle}/${name}"
  if [[ ! -f "${src}/SKILL.md" ]]; then
    echo "error: missing ${src}/SKILL.md" >&2
    exit 1
  fi
  copied+=("$(copy_skill_dir "${src}")")
done

if [[ ${#copied[@]} -eq 0 ]]; then
  echo "error: no skills copied from ${source_root}" >&2
  exit 1
fi

# Stable summary for the caller.
IFS=$'\n' sorted=($(printf '%s\n' "${copied[@]}" | sort))
unset IFS
printf '%s\n' "${sorted[@]}"
echo "copied ${#sorted[@]} skills to ${dest_skills} (source: ${source_root})"
