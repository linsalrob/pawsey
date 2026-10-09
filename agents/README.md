# Agent instructions

Shared instructions for AI coding agents (Claude Code and Codex CLI) on Pawsey
systems. They cover things like how to use Slurm, git safety rules and where
to find reference databases.

## What's here

| File | What it is |
|---|---|
| `AGENTS.md` | The main instructions every agent follows. Start here. |
| `AGENTS.claude.md` | Extra instructions for Claude Code only. |
| `AGENTS.codex.md` | Extra instructions for Codex CLI only. |
| `skills/` | Add-ons that let an agent ask ChatGPT or Claude for a second opinion. |
| `build.sh` | Installs everything into your home directory. |

## Install

```bash
git clone git@github.com:linsalrob/pawsey.git
pawsey/agents/build.sh
```

This puts the instructions where each agent reads them:
`~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`. If you already have your own
copies there, they are saved as `<file>.bak.<date>` first.

If you aren't `linsalrob`, set your own GitHub account before running
`build.sh`, and add the same lines to `~/.bashrc`:

```bash
export AGENT_GH_OWNER=your-github-name
export AGENT_HANDOFF_REPO=your-github-name/agent-handoffs   # optional
```

## Updating

Edit the files here, not the installed copies. Then run `build.sh` again.
After the first run, `git pull` reinstalls automatically.

Files are copied, not linked, because `/scratch` is purged after 21 days.
