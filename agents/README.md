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

### Optional

I use a private repository for handoffs between agents. If you want to use it, create a
GitHub repository called `agent-handoffs` and set it to private.

```bash
gh repo create agent-handoffs --private --clone
```

Then add the following lines to your `~/.bashrc`:

```bash
export AGENT_GH_OWNER=your-github-name
export AGENT_HANDOFF_REPO=your-github-name/agent-handoffs
```

Once you have done this you can connect ChatGPT and Claude Code to share instructions and code snippets. The handoff feature is optional, but it can be useful for sharing context between agents, and having them argue over the best solution to a problem.

(Note: if AGENT_HANDOFF_REPO is not set, the handoff feature will be disabled.)

### If you are already on setonix, the Pawsey HPC

```bash
~edwa0468/GitHubs/pawsey/agents/build.sh
```

### If that doesn't work, or you are on a different system, try this:

```bash
git clone git@github.com:linsalrob/pawsey.git
pawsey/agents/build.sh
```

This puts the instructions where each agent reads them:
`~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`. If you already have your own
copies there, they are saved as `<file>.bak.<date>` first.


## Updating

Edit the files here, not the installed copies. Then run `build.sh` again.
After the first run, `git pull` reinstalls automatically.

Files are copied, not linked, because `/scratch` is purged after 21 days.
