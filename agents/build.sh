#!/usr/bin/env bash
# Regenerates the per-agent AGENTS.md files that ~/.codex/AGENTS.md and
# ~/.claude/CLAUDE.md are symlinked to, by concatenating the shared base
# (AGENTS.md) with each agent's overlay (AGENTS.<agent>.md).
#
# Run this after editing AGENTS.md, AGENTS.codex.md, or AGENTS.claude.md.
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p generated

build() {
    local overlay="$1" out="$2" label="$3"
    {
        printf '<!-- GENERATED FILE — do not edit directly.\n'
        printf '     Source: AGENTS.md + %s in this directory.\n' "$overlay"
        printf '     Edit those, then rerun build.sh. -->\n\n'
        cat AGENTS.md
        printf '\n\n'
        cat "$overlay"
    } > "generated/$out"
    echo "Built generated/$out ($label)"
}

build AGENTS.codex.md  AGENTS.codex.md "-> ~/.codex/AGENTS.md"
build AGENTS.claude.md CLAUDE.md       "-> ~/.claude/CLAUDE.md"
