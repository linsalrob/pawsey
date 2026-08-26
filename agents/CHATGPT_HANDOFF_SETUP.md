# ChatGPT ↔ Codex handoff setup

This document describes how to install and use the `ask-chatgpt` Codex skill
stored in this repository.

The goal is simple:

```text
Codex CLI
   │
   │ "Ask ChatGPT ..."
   ▼
GitHub issue + optional compact evidence bundle
   │
   ▼
ChatGPT in the browser
   │
   │ ### PROMPT FOR CODEX
   ▼
same Codex CLI session
```

The same command works for both ordinary GitHub repositories and non-Git
scientific analysis directories.

## Files

The skill is stored at:

```text
codex/skills/ask-chatgpt/SKILL.md
```

Install it as a personal Codex skill under:

```text
~/.agents/skills/ask-chatgpt/
```

## Install by symlink

From the root of this `pawsey` repository:

```bash
mkdir -p ~/.agents/skills
ln -sfn "$(pwd)/codex/skills/ask-chatgpt" ~/.agents/skills/ask-chatgpt
```

A symlink is convenient because updates pulled into this repository immediately
update the installed skill.

If Codex does not notice a newly installed or updated skill, start a new Codex
session.

## Install by copy

If a symlink is inconvenient:

```bash
mkdir -p ~/.agents/skills/ask-chatgpt
cp codex/skills/ask-chatgpt/SKILL.md ~/.agents/skills/ask-chatgpt/SKILL.md
```

Remember that copied installations must be refreshed manually when this
repository changes.

## Invocation

Explicit invocation:

```text
$ask-chatgpt Should these two protein populations be analysed separately?
```

Natural invocation:

```text
Ask ChatGPT whether these two protein populations should be analysed separately.
```

The skill description deliberately contains `Ask ChatGPT` and `Ask Chatty` so
Codex can select it from natural language.

## GitHub authentication

The workflow expects the GitHub CLI to be authenticated:

```bash
gh auth status
```

The authenticated account must be able to:

- create issues in the current project repository when appropriate;
- read and write `linsalrob/chatgpt-handoffs`.

The shared handoff repository is private.

## Shared repository checkout

By default the skill uses:

```text
$HOME/.cache/chatgpt-handoffs
```

To keep the checkout elsewhere, set:

```bash
export CHATGPT_HANDOFF_DIR=/path/to/chatgpt-handoffs
```

On an HPC system, a persistent project/scratch location may be preferable if
home quota or inode usage is constrained.

For example:

```bash
export CHATGPT_HANDOFF_DIR="$MYSCRATCH/chatgpt-handoffs"
```

Use a location that persists for the duration of the analysis.

## Recommended prefix rules

The current Pawsey rules already contain broad permissions for common Git
operations such as `git add`, `git commit`, `git push`, `git clone`, and
`git status`. Add the following broad prefixes if equivalent rules are not
already present:

```python
prefix_rule(pattern=["gh", "issue", "create"], decision="allow")
prefix_rule(pattern=["gh", "issue", "view"], decision="allow")
prefix_rule(pattern=["gh", "repo", "view"], decision="allow")
prefix_rule(pattern=["gh", "repo", "clone"], decision="allow")
prefix_rule(pattern=["git", "pull", "--ff-only"], decision="allow")
```

These rules allow the handoff workflow without approving a different complete
command for every issue title, issue body, repository, or project.

Do not add a blanket:

```python
prefix_rule(pattern=["gh"], decision="allow")
```

unless unrestricted GitHub CLI access is genuinely intended.

## Behaviour inside a GitHub repository

When the current analysis is backed by a GitHub repository:

1. the issue is created in that repository;
2. committed repository state is used as the primary evidence;
3. the shared handoff repository is used only when local/untracked evidence,
   figures, or snippets would materially improve the consultation.

This keeps project-specific discussion with the project.

## Behaviour outside a GitHub repository

For non-Git analysis workspaces:

1. determine a stable project slug;
2. create or reuse
   `linsalrob/chatgpt-handoffs/projects/<project>/`;
3. create a compact evidence package under
   `projects/<project>/handoffs/<handoff-id>/`;
4. commit and push that package;
5. create the consultation issue in `linsalrob/chatgpt-handoffs`.

This is the normal path for scientific "vibe-analysis" sessions.

## Test

From a harmless test repository:

```text
Ask ChatGPT whether this repository's README explains the project clearly.
```

Codex should:

1. create one `[Ask ChatGPT] ...` issue;
2. print the issue URL;
3. finish with `### PASTE INTO CHATTY`.

From a non-Git directory, try:

```text
Ask ChatGPT what the most useful next analysis would be from the current results.
```

Codex should additionally create a project-specific handoff bundle in
`linsalrob/chatgpt-handoffs`.

## Safety boundary

The shared repository is deliberately for small derived evidence, not bulk data
storage.

Do not automatically put credentials, patient-identifiable information,
regulated data, large raw datasets, FASTQ/BAM collections, databases, model
weights, or complete output trees into GitHub.

Private repository status does not override data governance requirements.
