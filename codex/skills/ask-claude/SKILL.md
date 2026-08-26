---
name: ask-claude
description: >
  Hand a question, interpretation, or decision from the active CLI agent
  session (Codex, Claude Code, or another agent) to Claude (claude.ai) through
  GitHub. Mirrors the ask-chatgpt skill exactly, but targets Claude instead of
  ChatGPT — use this one when the user specifically wants Claude's opinion,
  not ChatGPT's. Trigger whenever the user says "Ask Claude", "ask Claude",
  "let's ask Claude", or explicitly invokes $ask-claude — AND whenever the
  agent itself judges, per AGENTS.md's External AI collaboration policy, that
  a consequential scientific, strategic, or design decision would materially
  benefit from Claude's input, even without being asked. Works both inside
  GitHub repositories and in non-Git scientific/vibe-analysis workspaces.
  Creates a durable GitHub issue, optionally creates a compact evidence bundle
  in linsalrob/claude-handoffs, and ends with a prompt the user can paste
  directly into Claude — clearly labelled so it is not confused with the
  ask-chatgpt skill's ChatGPT-bound prompt.
---

# Ask Claude

Create a durable, two-way handoff from the current CLI agent session to
Claude (claude.ai).

This is the mirror image of the `ask-chatgpt` skill: same workflow, same
handoff mechanics, different destination model and different shared
repository. If you are looking for the ChatGPT version, use `ask-chatgpt`
instead — do not confuse the two.

This skill runs the same way regardless of which CLI agent invokes it. Before
anything else, fix `<AGENT>` for the rest of this workflow:

- `Codex` when running inside Codex CLI;
- `Claude` when running inside Claude Code;
- the appropriate short name for any other CLI agent.

Use `<AGENT>` (and its all-caps form, e.g. `CODEX`, `CLAUDE`, for headings)
consistently everywhere below. Never leave the literal placeholder text
`<AGENT>` in real output — always substitute the actual name.

**Note when `<AGENT>` is itself `Claude`** (i.e. this is a Claude Code
session): consulting a separate Claude conversation from inside Claude Code
is still useful — fresh context, no priming from this session's history — but
it is not an independent second model. When the goal is a genuinely
independent second opinion rather than a fresh, unprimed pass, prefer
`ask-chatgpt` instead. Use judgement; either is legitimate depending on what
the user actually needs.

The user should be able to say:

    Ask Claude <question>

from essentially any session, whether or not the working directory is a Git
repository. The agent may also start this workflow entirely on its own —
see "Autonomous invocation" below.

The workflow must:

1. understand the question in the context of the active session;
2. gather the minimum context and evidence Claude needs;
3. create a GitHub issue;
4. when useful, create a small shared evidence bundle in
   `linsalrob/claude-handoffs`;
5. explicitly instruct Claude to finish with a paste-back prompt for
   `<AGENT>`;
6. end the response with a short prompt the user can paste into Claude —
   clearly labelled as being for Claude, not ChatGPT.

## Trigger

Run this workflow whenever the user says phrases such as:

- `Ask Claude`
- `Ask Claude whether ...`
- `Let's ask Claude ...`
- `$ask-claude ...`

The text following the trigger is normally the question for Claude.

If the user says only `Ask Claude`, infer the question from the current task
and the most recent unresolved scientific, strategic, design, or
implementation decision.

Do not ask the user to repeat context that is already available in the active
session.

Do not trigger this skill on a bare "Ask ChatGPT" / "Ask Chatty" phrase — that
is `ask-chatgpt`'s trigger, not this one. If the user's intent is ambiguous
between the two, ask which model they mean rather than guessing.

## Autonomous invocation

The agent is also authorised to start this workflow on its own judgement,
without any user trigger phrase, per AGENTS.md's "External AI collaboration"
policy. Reach for this when a task has hit a genuinely consequential,
uncertain, scientific, strategic, or design decision that would materially
benefit from a second, independent perspective — not for routine
implementation choices the agent can decide itself.

When invoking autonomously:

- briefly tell the user what question is being handed off and why, before or
  as the handoff is created — this should never happen silently;
- do not stop other in-scope work to wait for the answer; continue anything
  independent of it, per AGENTS.md;
- everything else in this skill (modes, evidence rules, issue structure,
  final paste-back block) applies exactly as it does for a user-triggered
  invocation.

Use judgement about frequency: this is for moments that matter, not a
routine step in every task.

## Two handoff modes

Determine which mode applies before creating anything.

### Mode A — GitHub-backed project

Use this mode when all of the following are true:

- the current workspace is inside a Git repository;
- the repository has a GitHub remote;
- `gh repo view` can identify the current GitHub repository.

Create the handoff issue in the current project's issue tracker.

Use repository files, commits, PRs, existing issues, and committed results as
the primary context.

A central evidence bundle in `linsalrob/claude-handoffs` is optional in this
mode. Create one only when material evidence needed by Claude is local,
untracked, inconvenient to add to the source repository, or better represented
as a deliberately small snapshot.

Do not commit unrelated local analysis outputs to the source repository merely
to make them visible to Claude.

### Mode B — non-Git or non-GitHub analysis workspace

Use this mode when the current workspace is not a usable GitHub-backed project.

Create the handoff issue in:

    linsalrob/claude-handoffs

Create a project-specific directory and a handoff evidence bundle there.

This is the normal mode for vibe-analysis directories, HPC analysis
workspaces, scratch directories, and other scientific sessions where the
analysis rather than a code repository is the primary artifact.

## Shared handoff repository

Repository:

    linsalrob/claude-handoffs

Preferred local checkout:

    ${CLAUDE_HANDOFF_DIR:-$HOME/.cache/claude-handoffs}

If the checkout exists:

    git -C "$HANDOFF_DIR" pull --ff-only

If it does not exist:

    gh repo clone linsalrob/claude-handoffs "$HANDOFF_DIR"

If the checkout cannot be updated safely because it has unrelated local
changes, do not discard them. Inspect the state, preserve the changes, and use
a safe alternative such as a separate temporary checkout.

Never use `git reset --hard` or `git clean` to make the handoff repository
usable.

## Determine the project name

For Mode A, use the current GitHub repository name as the default project
slug when a shared evidence bundle is required.

For Mode B, determine a concise stable project slug using this priority:

1. an explicit `project_slug` in a local `CLAUDE_HANDOFF.md`;
2. an existing matching project under
   `claude-handoffs/projects/`;
3. the project name or title in `SCIENTIFIC_BRIEF.md`;
4. the current working-directory basename.

Sanitize the slug for use as a directory name.

Prefer stable names such as:

    HAB
    VijiPhage
    Logan
    CF-metagenomes
    bronchiectasis

Do not create a new project directory on every invocation.

If the identity is obvious, proceed without asking the user.

## Project directory layout

For a project `<project>` in the shared repository, use:

    projects/<project>/
        PROJECT.md
        shared/
            snippets/
            figures/
        handoffs/
            <handoff-id>/
                README.md
                snippets/
                figures/

`PROJECT.md` contains durable context that is useful across multiple
consultations.

`shared/` contains only small reusable project-level artifacts.

`handoffs/<handoff-id>/` contains the evidence snapshot for one specific
Claude consultation.

Use a handoff ID such as:

    20260823-174500-maltschvirus-host

using a timestamp plus a short descriptive slug.

## Gather context

Before creating the issue, inspect enough of the current state to produce a
self-contained handoff.

Gather, where relevant:

- the user's overall objective;
- the exact question for Claude;
- what `<AGENT>` has already done;
- important findings and negative results;
- uncertainties and competing interpretations;
- relevant methods, parameters, sample counts, and transformations;
- relevant local files;
- current branch and HEAD when in a Git repository;
- relevant commits, PRs, issues, or repository paths;
- `<AGENT>`'s own current interpretation or recommendation;
- the next action `<AGENT>` would take if its recommendation is accepted.

Do not dump the complete session transcript.

Summarize intelligently.

## Scientific/vibe-analysis state

When files such as these exist, treat them as first-class handoff context:

    SCIENTIFIC_BRIEF.md
    ANALYSIS_PLAN.md
    STATUS.md
    DECISIONS.md
    reports/scientific_report.md
    CLAUDE_HANDOFF.md

Read the relevant portions before constructing the handoff.

When a substantial new result has already been established, update the local
scientific state files if doing so is part of the workspace's normal workflow
before creating the handoff. The handoff must not become a substitute for the
analysis workspace's durable scientific record.

## Decide whether an evidence bundle is needed

Create a shared evidence bundle when one or more of these are true:

- the session is Mode B;
- the question depends on local files Claude cannot otherwise inspect;
- a figure is central to the question;
- a large result needs to be reduced to a small table or summary;
- the relevant evidence is untracked and should not be committed to the source
  repository;
- a stable snapshot will make the consultation reproducible.

Do not create a bundle merely for ceremony when the GitHub issue plus committed
repository context is sufficient.

## Evidence selection principle

Create the **smallest evidence package that lets Claude reason well about the
question**.

Prefer derived summaries over raw data.

Good handoff artifacts include:

- concise Markdown summaries;
- small TSV or CSV tables;
- small JSON summaries;
- selected rows or columns from a large table;
- correlation or model-summary tables;
- compact diagnostic outputs;
- one or a few directly relevant figures;
- captions and notes explaining exactly what each artifact shows.

Avoid copying whole output directories.

## Size guidance

These are guidance limits, not targets:

- Markdown/text: preferably under 100 KB per file;
- TSV/CSV/JSON snippets: preferably under 1 MB per file;
- images: preferably under 5 MB each;
- total new material for one handoff: preferably under 10 MB.

If a source file is larger, derive a small summary, subset, aggregation, or
visualization specifically for the handoff.

Do not use Git LFS for handoff material. If an artifact seems to require LFS,
it probably does not belong in this repository.

## Sensitive-data rule

Never automatically copy any of the following into the handoff repository or
a GitHub issue:

- credentials, tokens, passwords, private keys, or secrets;
- personally identifying information not already intended for GitHub;
- patient-identifiable or regulated health data;
- confidential data whose sharing terms do not permit storage in this
  repository;
- large raw datasets merely because they are locally available.

The handoff repository is private, but privacy does not override data
governance, consent, contractual, ethics, or institutional restrictions.

For unpublished but non-sensitive research data, share only the minimum
derived evidence needed for the consultation.

## Figures

Figures are useful handoff evidence.

When adding a figure:

- include only figures directly relevant to the question;
- use a descriptive filename;
- describe the figure in the handoff `README.md`;
- state what data it contains and what comparison it represents;
- where practical, include a small supporting data table or quantitative
  summary.

Do not assume Claude can always render every repository-hosted binary
artifact. The handoff `README.md` must contain enough caption/summary
information for Claude to understand why the figure matters even if image
rendering is unavailable.

## Create or update PROJECT.md

If `projects/<project>/PROJECT.md` does not exist, create it using the shared
repository template.

Populate only information that is reasonably durable, for example:

- project name;
- scientific or analytical objective;
- high-level data description;
- important terminology;
- major persistent constraints;
- durable current findings;
- locations of important local source data, clearly marked as local-only.

Do not turn `PROJECT.md` into a chronological lab notebook.

Update it only when the new information is likely to matter to future
consultations.

## Create the handoff directory

For a handoff requiring shared evidence, create:

    projects/<project>/handoffs/<handoff-id>/

At minimum create:

    README.md

Optionally create:

    snippets/
    figures/

The handoff README should contain:

- the exact question;
- the objective;
- the current analysis state;
- what files are included;
- what each file represents;
- key quantitative facts;
- caveats;
- local-only files that were not copied;
- `<AGENT>`'s current assessment.

Commit and push the evidence bundle to `linsalrob/claude-handoffs` before
creating the issue so the issue can link to a stable committed location.

Use a concise commit message such as:

    Add HAB handoff on Maltschvirus host interpretation

Do not modify unrelated handoff projects.

## Issue title

Create a concise, specific title:

    [Ask Claude] <specific question or decision>

Good:

    [Ask Claude] Interpret the Logan protein entropy results
    [Ask Claude] Choose SNP distances or embeddings for VijiPhage clustering
    [Ask Claude] Assess evidence for a Maltschvirus bacterial host

Bad:

    [Ask Claude] Question
    Claude handoff
    Need advice

## Issue target

For Mode A:

    current GitHub repository

For Mode B:

    linsalrob/claude-handoffs

If Mode A uses a shared evidence bundle, the project issue must link directly
to the relevant path in `linsalrob/claude-handoffs`.

## Issue body

Construct the issue body with this structure (substituting `<AGENT>`
throughout, including its all-caps form where the template shows `AGENT`):

    # <AGENT> → Claude handoff

    ## Question for Claude

    <The exact question, clearly and prominently stated.>

    ## Objective

    <What the user is ultimately trying to achieve.>

    ## Current state

    <What has been done and what state the analysis/project is in.>

    For a GitHub-backed project include:
    Repository: <owner/repo>
    Branch: <branch>
    HEAD: <commit>

    For a non-Git analysis include:
    Session type: scientific/data-analysis workspace
    Working directory: <path>
    Git repository: none or not used for this analysis
    Shared project: linsalrob/claude-handoffs/projects/<project>/

    ## Important findings

    <The evidence and results that materially affect the question.>

    ## Supporting handoff material

    <If a shared evidence bundle exists, link to it and identify the most
    important files. If none exists, say that repository context is sufficient.>

    ## Relevant local or repository context

    <Relevant paths, commits, PRs, issues, analyses, commands, or local-only
    files. Clearly identify anything Claude cannot directly access.>

    ## <AGENT>'s current assessment

    <What <AGENT> thinks the answer or next step should be, and why. Be
    explicit about uncertainty.>

    ## What I need from Claude

    <The precise interpretation, critique, decision, plan, or recommendation
    required.>

    ## Instructions for Claude

    This issue is a handoff from an active <AGENT> CLI session.

    Please inspect this issue first. Then inspect relevant repository context
    and any linked supporting material in linsalrob/claude-handoffs where that
    would improve the answer.

    Answer the user's question directly. Be critical where appropriate, and
    distinguish evidence from interpretation or speculation.

    If you create a small durable text artifact that would materially help the
    continuing analysis, you may add it to the same handoff directory in
    linsalrob/claude-handoffs when GitHub write access is available. Do not
    overwrite <AGENT>-created evidence. Do not modify the source project
    repository unless the user explicitly asked you to.

    IMPORTANT: End your response with a section headed exactly:

    ### PROMPT FOR <AGENT (all-caps)>

    Under that heading, provide a single fenced text block containing a
    self-contained prompt that the user can paste directly into the existing
    <AGENT> session.

    That prompt must:
    - state the conclusion or decision you reached;
    - tell <AGENT> exactly what to do next;
    - preserve important constraints and caveats;
    - refer to this GitHub issue and the handoff directory where useful;
    - tell <AGENT> to inspect its current local state before acting;
    - tell <AGENT> to pull the shared handoff repository first if Claude
      added files there;
    - be operational rather than merely summarising the discussion.

    The prompt should allow <AGENT> to resume work immediately without the
    user having to explain the discussion again.

## Create the issue

Prefer the GitHub CLI.

Write the issue body to a temporary file and run:

    gh issue create \
        --repo "<target-owner/target-repo>" \
        --title "<title>" \
        --body-file "<temporary-file>"

Capture the issue URL returned by `gh issue create`.

Delete the temporary issue-body file afterwards.

If issue creation fails, report the error clearly and do not pretend the
handoff succeeded.

Never create more than one issue for one invocation unless the user explicitly
requests multiple consultations.

## Final response

After creating the issue, give the user the issue title and URL briefly.

Then END THE RESPONSE with exactly this section:

### PASTE INTO CLAUDE

*(Reminder: this is the `ask-claude` handoff. The block below is for a
**Claude** conversation at claude.ai — not ChatGPT. If you meant to ask
ChatGPT, use the `ask-chatgpt` skill instead.)*

```text
Please read this <AGENT> → Claude handoff issue:

<ISSUE_URL>

This comes from my active <AGENT> CLI session. Please inspect the issue and any
relevant repository context.

If the issue links to supporting material in
https://github.com/linsalrob/claude-handoffs, inspect the relevant project and
handoff directory as part of the analysis.

Please answer the question posed in the issue.

Most importantly, when you have finished your analysis, add your analyses to the
issue, and draft a brief response that I can provide back to <AGENT>. Most
communication should be through the issue, not through copy/paste. End your response with
a section called:

### PROMPT FOR <AGENT (all-caps)>

containing a self-contained prompt in a fenced text block that I can paste
directly back into my existing <AGENT> session so it can continue the work.
```

Substitute the real `<AGENT>` value (e.g. `Codex`, `CODEX`) everywhere it
appears in that block — never leave the literal placeholder text.

The `PASTE INTO CLAUDE` block, including the reminder line immediately above
it, must always be the final content emitted by this skill.

Do not put commentary after it.
