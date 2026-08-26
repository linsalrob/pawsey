#!/usr/bin/env bash
# Installs REAL COPIES (not symlinks) of the shared AGENTS.md config and
# skills into ~/.codex/ and ~/.claude/.
#
# Why copies instead of symlinks: this repo checkout lives under
# $HOME/GitHubs, which on this system is itself symlinked onto /scratch —
# subject to Pawsey's 21-day scratch purge policy. A symlink into a purged
# path breaks silently and takes down both agents' config with it. GitHub is
# the durable source of truth; run this script (after `git pull` if you're
# restoring onto a fresh /scratch) to (re)install working local copies.
#
# Re-run after editing AGENTS.md, AGENTS.codex.md, AGENTS.claude.md, or
# anything under skills/.
set -euo pipefail
cd "$(dirname "$0")"

echo "Removing any leftover symlinks at install targets..."
for l in ~/.codex/AGENTS.md ~/.claude/CLAUDE.md ~/.claude/AGENTS.md ~/.claude/skills; do
    if [ -L "$l" ]; then
        rm -f "$l"
        echo "  removed symlink: $l"
    fi
done
for skill_dir in skills/*/; do
    name=$(basename "$skill_dir")
    if [ -L ~/.codex/skills/"$name" ]; then
        rm -f ~/.codex/skills/"$name"
        echo "  removed symlink: ~/.codex/skills/$name"
    fi
done

install_file() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    rm -f "$dst"
    cp "$src" "$dst"
    echo "Installed $dst"
}

# --- AGENTS.md (Codex) / CLAUDE.md (Claude Code) ---

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

build_combined() {
    local overlay="$1" out="$2"
    {
        printf '<!-- INSTALLED FILE — do not edit directly.\n'
        printf '     Source: agents/AGENTS.md + agents/%s in linsalrob/pawsey.\n' "$overlay"
        printf '     Edit those, commit, push, then rerun agents/build.sh. -->\n\n'
        cat AGENTS.md
        printf '\n\n'
        cat "$overlay"
    } > "$out"
}

build_combined AGENTS.codex.md  "$tmp/AGENTS.codex.md"
build_combined AGENTS.claude.md "$tmp/CLAUDE.md"

install_file "$tmp/AGENTS.codex.md" ~/.codex/AGENTS.md
install_file "$tmp/CLAUDE.md"       ~/.claude/CLAUDE.md
install_file AGENTS.md              ~/.claude/AGENTS.md   # plain shared base, manual reference only

# --- Skills ---

for skill_dir in skills/*/; do
    name=$(basename "$skill_dir")
    install_file "$skill_dir/SKILL.md" ~/.codex/skills/"$name"/SKILL.md
    install_file "$skill_dir/SKILL.md" ~/.claude/skills/"$name"/SKILL.md
done

echo "Done. Everything above is a plain file copy — rerun build.sh after any source edit or after restoring this checkout from GitHub."
