---
name: ask-chatgpt
description: >
  Hand a question, interpretation, or decision from an active Codex session to
  ChatGPT through GitHub. Trigger whenever the user says "Ask ChatGPT",
  "ask ChatGPT", "Ask Chatty", "ask Chatty", "let's ask ChatGPT", or explicitly
  invokes $ask-chatgpt. Works both inside GitHub repositories and in non-Git
  scientific/vibe-analysis workspaces. Creates a durable GitHub issue, optionally
  creates a compact evidence bundle in linsalrob/chatgpt-handoffs, and ends with
  a prompt the user can paste directly into ChatGPT.
---

# Ask ChatGPT

Create a durable, two-way handoff from the current Codex CLI session to
ChatGPT.

The user should be able to say:

    Ask ChatGPT <question>

from essentially any Codex session, whether or not the working directory is a
Git repository.

The workflow must:

1. understand the question in the context of the active Codex session;
2. gather the minimum context and evidence ChatGPT needs;
3. create a GitHub issue;
4. when useful, create a small shared evidence bundle in
   `linsalrob/chatgpt-handoffs`;
5. explicitly instruct ChatGPT to finish with a paste-back prompt for Codex;
6. end the Codex response with a short prompt the user can paste into ChatGPT.

## Trigger

Run this workflow whenever the user says phrases such as:

- `Ask ChatGPT`
- `Ask Chatty`
- `Ask ChatGPT whether ...`
- `Ask Chatty what she thinks about ...`
- `Let's ask ChatGPT ...`
- `$ask-chatgpt ...`

The text following the trigger is normally the question for ChatGPT.

If the user says only `Ask ChatGPT` or `Ask Chatty`, infer the question from the
current task and the most recent unresolved scientific, strategic, design, or
implementation decision.

Do not ask the user to repeat context that is already available in the active
session.

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

A central evidence bundle in `linsalrob/chatgpt-handoffs` is optional in this
mode. Create one only when material evidence needed by ChatGPT is local,
untracked, inconvenient to add to the source repository, or better represented
as a deliberately small snapshot.

Do not commit unrelated local analysis outputs to the source repository merely
to make them visible to ChatGPT.

### Mode B — non-Git or non-GitHub analysis workspace

Use this mode when the current workspace is not a usable GitHub-backed project.

Create the handoff issue in:

    linsalrob/chatgpt-handoffs

Create a project-specific directory and a handoff evidence bundle there.

This is the normal mode for vibe-analysis directories, HPC analysis
workspaces, scratch directories, and other scientific sessions where the
analysis rather than a code repository is the primary artifact.

## Shared handoff repository

Repository:

    linsalrob/chatgpt-handoffs

Preferred local checkout:

    ${CHATGPT_HANDOFF_DIR:-$HOME/.cache/chatgpt-handoffs}

If the checkout exists:

    git -C "$HANDOFF_DIR" pull --ff-only

If it does not exist:

    gh repo clone linsalrob/chatgpt-handoffs "$HANDOFF_DIR"

If the checkout cannot be updated safely because it has unrelated local
changes, do not discard them. Inspect the state, preserve the changes, and use
a safe alternative such as a separate temporary checkout.

Never use `git reset --hard` or `git clean` to make the handoff repository
usable.

## Determine the project name

For Mode A, use the current GitHub repository name as the default project
slug when a shared evidence bundle is required.

For Mode B, determine a concise stable project slug using this priority:

1. an explicit `project_slug` in a local `CHATGPT_HANDOFF.md`;
2. an existing matching project under
   `chatgpt-handoffs/projects/`;
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
ChatGPT consultation.

Use a handoff ID such as:

    20260823-174500-maltschvirus-host

using a timestamp plus a short descriptive slug.

## Gather context

Before creating the issue, inspect enough of the current state to produce a
self-contained handoff.

Gather, where relevant:

- the user's overall objective;
- the exact question for ChatGPT;
- what Codex has already done;
- important findings and negative results;
- uncertainties and competing interpretations;
- relevant methods, parameters, sample counts, and transformations;
- relevant local files;
- current branch and HEAD when in a Git repository;
- relevant commits, PRs, issues, or repository paths;
- Codex's own current interpretation or recommendation;
- the next action Codex would take if its recommendation is accepted.

Do not dump the complete Codex transcript.

Summarize intelligently.

## Scientific/vibe-analysis state

When files such as these exist, treat them as first-class handoff context:

    SCIENTIFIC_BRIEF.md
    ANALYSIS_PLAN.md
    STATUS.md
    DECISIONS.md
    reports/scientific_report.md
    CHATGPT_HANDOFF.md

Read the relevant portions before constructing the handoff.

When a substantial new result has already been established, update the local
scientific state files if doing so is part of the workspace's normal workflow
before creating the handoff. The handoff must not become a substitute for the
analysis workspace's durable scientific record.

## Decide whether an evidence bundle is needed

Create a shared evidence bundle when one or more of these are true:

- the session is Mode B;
- the question depends on local files ChatGPT cannot otherwise inspect;
- a figure is central to the question;
- a large result needs to be reduced to a small table or summary;
- the relevant evidence is untracked and should not be committed to the source
  repository;
- a stable snapshot will make the consultation reproducible.

Do not create a bundle merely for ceremony when the GitHub issue plus committed
repository context is sufficient.

## Evidence selection principle

Create the **smallest evidence package that lets ChatGPT reason well about the
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

Do not assume ChatGPT can always render every repository-hosted binary artifact.
The handoff `README.md` must contain enough caption/summary information for
ChatGPT to understand why the figure matters even if image rendering is
unavailable.

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
- Codex's current assessment.

Commit and push the evidence bundle to `linsalrob/chatgpt-handoffs` before
creating the issue so the issue can link to a stable committed location.

Use a concise commit message such as:

    Add HAB handoff on Maltschvirus host interpretation

Do not modify unrelated handoff projects.

## Issue title

Create a concise, specific title:

    [Ask ChatGPT] <specific question or decision>

Good:

    [Ask ChatGPT] Interpret the Logan protein entropy results
    [Ask ChatGPT] Choose SNP distances or embeddings for VijiPhage clustering
    [Ask ChatGPT] Assess evidence for a Maltschvirus bacterial host

Bad:

    [Ask ChatGPT] Question
    ChatGPT handoff
    Need advice

## Issue target

For Mode A:

    current GitHub repository

For Mode B:

    linsalrob/chatgpt-handoffs

If Mode A uses a shared evidence bundle, the project issue must link directly
to the relevant path in `linsalrob/chatgpt-handoffs`.

## Issue body

Construct the issue body with this structure:

    # Codex → ChatGPT handoff

    ## Question for ChatGPT

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
    Shared project: linsalrob/chatgpt-handoffs/projects/<project>/

    ## Important findings

    <The evidence and results that materially affect the question.>

    ## Supporting handoff material

    <If a shared evidence bundle exists, link to it and identify the most
    important files. If none exists, say that repository context is sufficient.>

    ## Relevant local or repository context

    <Relevant paths, commits, PRs, issues, analyses, commands, or local-only
    files. Clearly identify anything ChatGPT cannot directly access.>

    ## Codex's current assessment

    <What Codex thinks the answer or next step should be, and why. Be explicit
    about uncertainty.>

    ## What I need from ChatGPT

    <The precise interpretation, critique, decision, plan, or recommendation
    required.>

    ## Instructions for ChatGPT

    This issue is a handoff from an active Codex CLI session.

    Please inspect this issue first. Then inspect relevant repository context
    and any linked supporting material in linsalrob/chatgpt-handoffs where that
    would improve the answer.

    Answer the user's question directly. Be critical where appropriate, and
    distinguish evidence from interpretation or speculation.

    If you create a small durable text artifact that would materially help the
    continuing analysis, you may add it to the same handoff directory in
    linsalrob/chatgpt-handoffs when GitHub write access is available. Do not
    overwrite Codex-created evidence. Do not modify the source project
    repository unless the user explicitly asked you to.

    IMPORTANT: End your response with a section headed exactly:

    ### PROMPT FOR CODEX

    Under that heading, provide a single fenced text block containing a
    self-contained prompt that the user can paste directly into the existing
    Codex CLI session.

    That prompt must:
    - state the conclusion or decision you reached;
    - tell Codex exactly what to do next;
    - preserve important constraints and caveats;
    - refer to this GitHub issue and the handoff directory where useful;
    - tell Codex to inspect its current local state before acting;
    - tell Codex to pull the shared handoff repository first if ChatGPT added
      files there;
    - be operational rather than merely summarising the discussion.

    The prompt should allow Codex to resume work immediately without the user
    having to explain the discussion again.

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

## Final Codex response

After creating the issue, give the user the issue title and URL briefly.

Then END THE RESPONSE with exactly this section:

### PASTE INTO CHATTY

```text
Please read this Codex → ChatGPT handoff issue:

<ISSUE_URL>

This comes from my active Codex CLI session. Please inspect the issue and any
relevant repository context.

If the issue links to supporting material in
https://github.com/linsalrob/chatgpt-handoffs, inspect the relevant project and
handoff directory as part of the analysis.

Please answer the question posed in the issue.

Most importantly, when you have finished your analysis, end your response with
a section called:

### PROMPT FOR CODEX

containing a self-contained prompt in a fenced text block that I can paste
directly back into my existing Codex CLI session so it can continue the work.
```

The `PASTE INTO CHATTY` block must always be the final content emitted by this
skill.

Do not put commentary after it.
