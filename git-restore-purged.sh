#!/usr/bin/env bash
# Restore tracked files that vanished from the working tree — e.g. after
# Pawsey's 21-day /scratch purge ate a checkout under $HOME/GitHubs.
#
#   git restore-purged              # current repo
#   git restore-purged REPO [REPO…] # named repos
#   git restore-purged --all        # every repo under ~/GitHubs
#   git restore-purged --dry-run …  # report only, change nothing
#
# Every step is additive: it restores files that are already missing and
# re-downloads objects. It never touches modified files, never resets, and
# never deletes anything.

set -uo pipefail

GITHUBS="${GITHUBS_DIR:-$HOME/GitHubs}"
DRY=0
rc=0

die()  { printf '%s\n' "$*" >&2; exit 1; }
warn() { printf '  !! %s\n' "$*" >&2; }
info() { printf '  %s\n' "$*"; }

# Match the actual damage signatures only. Treating *any* fsck output as
# damage gives false positives: fsck also emits benign notices, and right
# after a --refetch it can report transient state that resolves on its own.
objects_broken() {
    git -C "$1" fsck --no-progress --no-dangling 2>&1 \
        | grep -qE 'missing (blob|tree|commit)|broken link|corrupt|unable to read'
}

restore_one() {
    local repo root n upstream ahead
    repo="$1"

    root=$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null) || {
        if [ -d "$repo/.git" ]; then
            # The purge deletes files, not directories: .git/HEAD, config and
            # index are files, so a hard-hit checkout keeps a .git skeleton of
            # empty dirs. Nothing here is repairable — it needs a fresh clone.
            printf '==> %s\n' "$repo"
            warn "GUTTED: .git exists but has no HEAD/config — re-clone required"
            warn "        surviving worktree files: $(find "$repo" -path "$repo/.git" -prune -o -type f -print 2>/dev/null | wc -l)"
        else
            warn "not a git repo: $repo"
        fi
        rc=1; return
    }
    printf '==> %s\n' "$root"

    # Objects for unpushed commits exist nowhere else. If those were purged,
    # no fetch can bring them back — say so rather than failing silently.
    upstream=$(git -C "$root" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
    if [ -n "$upstream" ]; then
        ahead=$(git -C "$root" rev-list --count "$upstream"..HEAD 2>/dev/null || echo 0)
        [ "${ahead:-0}" -gt 0 ] && warn "$ahead unpushed commit(s) — not on any remote"
    else
        warn "no upstream for current branch"
    fi

    if objects_broken "$root"; then
        if [ "$DRY" = 1 ]; then
            info "object store damaged — would run: git fetch --refetch origin"
        elif git -C "$root" remote get-url origin >/dev/null 2>&1; then
            info "object store damaged — re-downloading from origin…"
            # --refetch skips negotiation, so it resends objects git wrongly
            # believes we still have. A plain fetch is a no-op here.
            git -C "$root" fetch --refetch origin >/dev/null 2>&1 \
                || { warn "fetch failed — offline, or no access to origin"; rc=1; return; }
            objects_broken "$root" && {
                warn "STILL incomplete after refetch — likely unpushed work that is now unrecoverable"
                rc=1
            }
        else
            warn "objects missing and no origin remote to restore from"; rc=1; return
        fi
    fi

    # .git/index is a file, so the purge takes it too. With no index git
    # reports every tracked file as a *staged* deletion — invisible to
    # ls-files --deleted. Nothing there is intentional and there are no real
    # staged changes to lose, so rebuild index and worktree from HEAD.
    if [ ! -f "$(git -C "$root" rev-parse --absolute-git-dir)/index" ]; then
        if [ "$DRY" = 1 ]; then
            info "index purged — would rebuild index+worktree from HEAD"
        else
            info "index purged — rebuilding index and worktree from HEAD"
            git -C "$root" restore --source=HEAD --staged --worktree -- . \
                || { warn "rebuild failed"; rc=1; return; }
            n=$(git -C "$root" ls-files --deleted | wc -l)
        fi
    fi

    n=$(git -C "$root" ls-files --deleted | wc -l)
    if [ "$n" -eq 0 ]; then
        info "nothing missing"
        return
    fi
    if [ "$DRY" = 1 ]; then
        info "would restore $n file(s)"
        git -C "$root" ls-files --deleted | sed 's/^/     /' | head -10
        [ "$n" -gt 10 ] && info "   … and $((n - 10)) more"
        return
    fi

    # Agent config is installed as copies into ~/.codex and ~/.claude, and the
    # post-merge hook that reinstalls them only fires on a pull — never on a
    # restore. So a purge that ate agents/* leaves the installed copies stale
    # with nothing to flag it. Catch that here.
    local needs_build=0
    git -C "$root" ls-files --deleted | grep -q '^agents/' \
        && [ -x "$root/agents/build.sh" ] && needs_build=1

    # Only paths git reports as MISSING. Modified files are never touched.
    git -C "$root" ls-files -z --deleted \
        | xargs -0 -r git -C "$root" restore --worktree -- \
        || { warn "restore failed"; rc=1; return; }

    info "restored $n file(s)"
    [ "$needs_build" = 1 ] && info "agents/ was restored — run: $root/agents/build.sh"
    local left
    left=$(git -C "$root" ls-files --deleted | wc -l)
    [ "$left" -ne 0 ] && { warn "$left still missing"; rc=1; }
    return 0
}

repos=()
for arg in "$@"; do
    case "$arg" in
        -n|--dry-run) DRY=1 ;;
        -a|--all)
            [ -d "$GITHUBS" ] || die "no such directory: $GITHUBS"
            for d in "$GITHUBS"/*/; do
                [ -e "$d/.git" ] && repos+=("$d")
            done ;;
        -h|--help) sed -n '2,13p' "$0" | sed 's/^# \?//'; exit 0 ;;
        -*) die "unknown option: $arg" ;;
        *)  repos+=("$arg") ;;
    esac
done
[ ${#repos[@]} -eq 0 ] && repos=("$PWD")

for r in "${repos[@]}"; do restore_one "$r"; done
exit $rc
