#!/usr/bin/env bash
set -euo pipefail

# Sequential install for every supported agent.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/apply-to.sh" claude codex cursor grok
