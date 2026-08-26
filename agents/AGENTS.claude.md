## Claude Code overlay

Everything above this heading is the shared base (`AGENTS.md`), common to
every CLI agent. Everything from here down is Claude-Code-specific and is
only appended when building `generated/CLAUDE.md` (see the "Scope and
provenance" section above). Edit this file, not the shared base, for
anything that applies to Claude Code and no other agent.

Claude Code auto-loads `~/.claude/CLAUDE.md` as global user memory — it does
**not** auto-load `AGENTS.md`. That's the entire reason this split exists:
`generated/CLAUDE.md` (shared base + this file) is what actually gets
symlinked to `~/.claude/CLAUDE.md` so this policy is picked up automatically
at the start of every session, instead of only when someone tells Claude to
go read `AGENTS.md` by hand.

For the shared base's `<AGENT>` placeholders (used in the "External AI
collaboration" section and by the `ask-chatgpt` / `ask-claude` skills): this
session's `<AGENT>` is `Claude` (`CLAUDE` in all-caps contexts).

### Relationship to Claude Code's own permission system

The shared base's "Pre-approved routine commands" section (and similar
approval language elsewhere in it) states *policy* — what the user considers
acceptable to do without asking again. It does not bypass or configure Claude
Code's own tool-approval mechanism (the permission-mode prompts, and any
allow/deny rules in `.claude/settings.json` / `settings.local.json`). If the
harness still prompts for something this document pre-approves, that prompt
is Claude Code's own permission system doing its job, not a policy conflict —
answer it, and consider adding the command to an allowlist (see the
`fewer-permission-prompts` skill) if it recurs often.

### Context7 MCP

As of 2026-08-26, no MCP servers are configured for this Claude Code account
(`mcpServers` is empty). Treat the shared base's Context7 guidance as
inactive until an MCP config actually wires it up — fall back to official
version-matched documentation in the meantime.

### Claude Code's built-in systems

Claude Code's own skills, subagents, persistent memory, and artifact tooling
are documented in its own system prompt and don't need restating here. This
overlay exists only to add Pawsey-specific policy on top of that — it is not
the place to redescribe how Claude Code already works.
