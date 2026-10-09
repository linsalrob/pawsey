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
# anything under skills/. This script also wires up a post-merge git hook
# (see hooks/post-merge) so it reruns itself automatically after future
# `git pull`s — you only need to run it by hand once per fresh checkout.
#
# Other users can run this from their own clone. Two settings personalise the
# installed copies (export them in ~/.bashrc so the post-merge hook sees them
# too):
#   AGENT_GH_OWNER      GitHub owner used in the pre-approved `gh` commands
#                       (default: linsalrob)
#   AGENT_HANDOFF_REPO  repo the ask-chatgpt / ask-claude skills push evidence
#                       bundles to (default: $AGENT_GH_OWNER/agent-handoffs)
#
# Before overwriting an install target, any existing file that this script
# did not write (or that has been edited since) is backed up alongside it as
# <file>.bak.<timestamp>. What this script last wrote is recorded, with
# checksums, in ~/.config/pawsey-agents/installed.sha256.
set -euo pipefail
cd "$(dirname "$0")"

AGENT_GH_OWNER="${AGENT_GH_OWNER:-linsalrob}"
AGENT_HANDOFF_REPO="${AGENT_HANDOFF_REPO:-$AGENT_GH_OWNER/agent-handoffs}"
echo "GitHub owner: $AGENT_GH_OWNER    handoff repo: $AGENT_HANDOFF_REPO"

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

manifest=~/.config/pawsey-agents/installed.sha256
mkdir -p "$(dirname "$manifest")"
touch "$manifest"
stamp=$(date +%Y%m%d-%H%M%S)

install_file() {
    local src="$1" dst="$2" cur recorded
    mkdir -p "$(dirname "$dst")"
    # Back up an existing file unless it is identical to what we're about to
    # install, or is exactly what this script installed last time.
    if [ -f "$dst" ] && ! cmp -s "$src" "$dst"; then
        cur=$(sha256sum "$dst" | cut -d' ' -f1)
        recorded=$(awk -F'\t' -v p="$dst" '$2 == p { print $1 }' "$manifest")
        if [ "$cur" != "$recorded" ]; then
            cp -p "$dst" "$dst.bak.$stamp"
            echo "  backed up $dst -> $dst.bak.$stamp"
        fi
    fi
    rm -f "$dst"
    cp "$src" "$dst"
    {
        awk -F'\t' -v p="$dst" '$2 != p' "$manifest"
        printf '%s\t%s\n' "$(sha256sum "$dst" | cut -d' ' -f1)" "$dst"
    } > "$manifest.tmp"
    mv "$manifest.tmp" "$manifest"
    echo "Installed $dst"
}

# Substitute the per-user GitHub owner and handoff repo into a source file.
personalise() {
    sed -e "s#linsalrob/agent-handoffs#${AGENT_HANDOFF_REPO}#g" \
        -e "s#--repo linsalrob/#--repo ${AGENT_GH_OWNER}/#g" \
        -e "s#repos/linsalrob/#repos/${AGENT_GH_OWNER}/#g" \
        "$1"
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
        personalise AGENTS.md
        printf '\n\n'
        personalise "$overlay"
    } > "$out"
}

build_combined AGENTS.codex.md  "$tmp/AGENTS.codex.md"
build_combined AGENTS.claude.md "$tmp/CLAUDE.md"
personalise AGENTS.md > "$tmp/AGENTS.md"

install_file "$tmp/AGENTS.codex.md" ~/.codex/AGENTS.md
install_file "$tmp/CLAUDE.md"       ~/.claude/CLAUDE.md
install_file "$tmp/AGENTS.md"       ~/.claude/AGENTS.md   # plain shared base, manual reference only

# --- Skills ---

for skill_dir in skills/*/; do
    name=$(basename "$skill_dir")
    personalise "$skill_dir/SKILL.md" > "$tmp/$name.SKILL.md"
    install_file "$tmp/$name.SKILL.md" ~/.codex/skills/"$name"/SKILL.md
    install_file "$tmp/$name.SKILL.md" ~/.claude/skills/"$name"/SKILL.md
done

# --- Git hook: auto-reinstall after `git pull` ---
# Wires .git/hooks/post-merge (untracked, per-checkout) to the tracked
# agents/hooks/post-merge, so a fresh checkout gets this on the first manual
# build.sh run and every later `git pull` reinstalls itself automatically.

git_dir=$(git rev-parse --git-dir 2>/dev/null || true)
if [ -n "$git_dir" ]; then
    hook_target="$(pwd)/hooks/post-merge"
    hook_path="$git_dir/hooks/post-merge"
    if [ ! -e "$hook_path" ] || [ -L "$hook_path" ]; then
        ln -sf "$hook_target" "$hook_path"
        echo "Linked git hook: $hook_path -> $hook_target"
    else
        echo "NOTE: $hook_path exists and isn't a symlink this script manages — leaving it alone."
    fi
fi

echo "Done. Everything above is a plain file copy — rerun build.sh after any source edit or after restoring this checkout from GitHub."
