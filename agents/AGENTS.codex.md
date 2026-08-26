## Codex CLI overlay

Everything above this heading is the shared base (`AGENTS.md`), common to
every CLI agent. Everything from here down is Codex-CLI-specific and is only
appended when building `generated/AGENTS.codex.md` (see the "Scope and
provenance" section above). Edit this file, not the shared base, for anything
that applies to Codex CLI and no other agent.

For the shared base's `<AGENT>` placeholders (used in the "External AI
collaboration" section and by the `ask-chatgpt` / `ask-claude` skills): this
session's `<AGENT>` is `Codex` (`CODEX` in all-caps contexts).

### Codex CLI GitHub helper scripts

Codex CLI provides bundled GitHub helper scripts via its plugin cache. The
following are approved with Python 3.11:

```text
python3.11 ~/.codex/plugins/cache/openai-curated-remote/github/*/skills/gh-fix-ci/scripts/inspect_pr_checks.py ...
python3.11 ~/.codex/plugins/cache/openai-curated-remote/github/*/skills/gh-address-comments/scripts/fetch_comments.py ...
```

This path is specific to Codex CLI's plugin cache — it will not exist under
another agent's home directory. Do not assume an equivalent script exists
elsewhere unless you have actually located it.

### Context7 MCP

As of 2026-08-26, no Context7 (or other) MCP server is configured for Codex
CLI on this system. Treat the shared base's Context7 guidance as inactive
until an MCP config actually wires it up — fall back to official
version-matched documentation in the meantime.
