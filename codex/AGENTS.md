# Global Codex Guidance (`~/.codex/AGENTS.md`)

Global working agreements for Codex CLI. These instructions apply when no more specific repository or subdirectory guidance overrides them.

## Instruction precedence

- System, developer, platform-security, sandbox, and execution-environment requirements take precedence over this file.
- Then follow explicit user instructions for the current task.
- Then follow the nearest repository or subdirectory `AGENTS.md`.
- Use this global file as the default when no more specific instruction applies.
- Repository-specific instructions may specialise these defaults but must not weaken safety rules concerning secrets, destructive operations, or unrelated user changes.
- When instructions conflict, identify the conflict and follow the more specific non-destructive instruction.

## Core operating principles

- Begin by identifying:
  1. the goal and acceptance criteria;
  2. constraints involving scope, safety, time, compute, or data;
  3. the files, commands, tests, documentation, or external sources that must be inspected;
  4. whether the request depends on current or version-specific information.
- Prefer safe, reversible, and workspace-scoped actions.
- Perform useful read-only inspection before asking questions.
- Ask a focused question only when the answer would materially change the implementation or when proceeding could cause destructive or difficult-to-reverse consequences.
- Otherwise, make the narrowest reasonable assumption, state it when material, and continue.
- Do not claim that a command, test, build, deployment, or validation succeeded unless it was actually run successfully.

## Accuracy, recency, and sourcing

When a request depends on recency, including words such as “latest”, “current”, “today”, or “as of now”:

1. Establish the current date and time.
   - Preferred local command: `date -Is`.
   - State the relevant date explicitly when it affects the answer.

2. Prefer official and primary sources:
   - upstream vendor documentation;
   - versioned language, framework, library, cloud, or tool documentation;
   - release notes and changelogs;
   - standards, specifications, research papers, or official advisories.

3. Prefer the most recent authoritative information:
   - confirm the target version;
   - use documentation matching that version;
   - record publication, release, or advisory dates when relevant;
   - cross-check multiple authoritative sources when details are safety-, security-, or compatibility-sensitive.

### Context7 MCP

- Use Context7 when it is available and appropriate for targeted library or API documentation; otherwise use official version-matched documentation.
- If known, pin the library using slash syntax, for example `use library /supabase/supabase`.
- State or determine the target version.
- Retrieve only the documentation needed for the task.
- Summarise relevant details rather than copying large documentation sections.

### Web search policy

- Use web search when required by higher-level policy or when it materially improves correctness, such as for current APIs, security advisories, release notes, compatibility changes, or recent external information.
- Prefer official documentation and primary sources.
- Use reputable, widely cited secondary sources only when primary sources are unavailable or insufficient.
- Include publication, release, or advisory dates in the response when they materially affect the conclusion.

## Existing workspace state

- Assume uncommitted changes belong to the user.
- Never revert, delete, overwrite, reformat, stage, or commit unrelated changes.
- Inspect `git status` and relevant diffs before editing a repository.
- Identify whether requested changes overlap existing user modifications.
- Preserve both sets of changes where possible and clearly report any conflict.
- Do not use destructive cleanup commands such as `git reset --hard`, `git clean -fd`, or broad recursive deletion unless explicitly requested.
- Do not remove or replace files merely because they appear unused without confirming they are within scope.

## Default autonomy and safety

- Default to read-only exploration and analysis until edits are required.
- When editing, keep changes inside the intended workspace or repository.
- Prefer the smallest safe action that completes the requested task.
- Do not modify production systems, production data, remote services, or external resources unless the user explicitly requests that operation.
- Use preview, validation, or dry-run modes when they are supported and materially useful.
- Never perform destructive remote operations merely because credentials or authenticated tools are available.

## Routine command execution

Codex may run non-destructive commands needed to inspect and validate the workspace without asking again, including:

- file and repository inspection;
- `git status`, `git diff`, and read-only history inspection;
- repository-defined formatting, linting, type-checking, testing, and build commands;
- targeted dependency metadata and documentation queries;
- commands that inspect environment, scheduler, accelerator, filesystem, or tool versions.

Commands that alter remote state, delete data, rewrite history, change machine-wide configuration, or modify production resources remain subject to the restrictions below.

## Execution environment

- Use the repository’s existing environment and tooling conventions.
- Prefer existing Docker, Apptainer/Singularity, Conda/Mamba, uv, virtualenv, Nix, module, or task-runner workflows over creating a new environment.
- Do not install system packages or modify host configuration unless explicitly instructed.
- Use an isolated environment when dependencies must be installed.
- Do not introduce Dockerfiles, container definitions, lockfiles, or environment manifests unless they are required by the task or requested by the user.
- If the repository already has a container or environment workflow, follow it.
- For HPC repositories, respect documented scheduler, module, filesystem, accelerator, and container conventions.
- Do not assume Docker is appropriate on an HPC system when Apptainer/Singularity, environment modules, or a scheduler-native workflow is established.

## Dependencies

- Prefer existing dependencies and standard-library functionality.
- Add or upgrade dependencies only when justified by the task.
- Before changing dependencies, inspect the repository’s package-management and lockfile conventions.
- Use the project’s established package manager.
- Update and preserve the appropriate lockfile when dependency changes require it.
- Avoid major-version upgrades or broad dependency refreshes unless requested.
- Avoid replacing one dependency ecosystem with another without explicit justification.
- Explain newly added runtime dependencies in the final summary.

## Editing files

- Make the smallest safe change that solves the issue.
- Preserve existing style, architecture, naming, and conventions.
- Prefer patch-style edits and small reviewable diffs over full-file rewrites.
- Modify only files necessary for the requested outcome.
- Do not perform opportunistic refactors, repository-wide formatting, dependency refreshes, or unrelated cleanup.
- Do not manually edit vendored, generated, minified, lock, migration, snapshot, or derived files unless the repository workflow requires it.
- Regenerate derived files using the authoritative project command where possible.
- Preserve file encoding, line-ending conventions, and executable permissions unless the task requires changing them.

## Git workflow

- Inspect `git status`, the current branch, and recent history before editing.
- Use the current non-default task branch when suitable. Create or switch branches when requested, required by repository guidance, or necessary to avoid committing substantial work directly to the default branch. Do not create or switch branches for read-only or trivial tasks.
- Never switch branches with a dirty working tree unless doing so is demonstrably safe.
- Do not create a branch for read-only analysis or trivial tasks.
- When committing, create focused commits with descriptive messages that follow the repository’s conventions.
- Do not amend, squash, rebase, or rewrite existing commits unless explicitly requested.
- Do not stage or commit unrelated user changes.
- Do not fetch, switch branches, create branches, or otherwise mutate Git metadata for a read-only review unless current remote state is necessary.

## Version updates for pull requests

- Follow the repository’s documented release and versioning policy.
- Increment a version when the user requests it, repository guidance requires it, or existing project practice clearly couples behavior-changing pull requests to version changes.
- Do not add a version bump when versions are release-managed, tag-derived, or automated unless the established workflow requires a source-file change.
- Determine the authoritative version source and affected package or workspace member before editing.
- Follow the project’s existing scheme; do not assume semantic versioning when the repository uses another convention.
- Under semantic versioning, use patch for backward-compatible fixes, minor for backward-compatible functionality, and major for intentional breaking changes. Treat pre-1.0 conventions according to repository policy.
- Update lockfiles, generated metadata, changelogs, or documentation only when required by the established release workflow.
- Include any version change in the pull-request summary.
- If the authoritative version source or appropriate increment cannot be determined, do not guess; ask the user when the choice blocks the task or report that no version was changed.
- In a workspace or monorepo, change only the version of the affected publishable unit unless the repository’s coordinated-release policy requires otherwise.

## Remote operations

- Non-destructive local repository operations may be performed without additional approval when relevant to the requested task. Discarding changes, destructive cleanup, deleting branches, or rewriting history requires explicit authorization.
- Remote write operations, including `git push`, creating or modifying pull requests, merging, publishing releases, modifying issues, or changing repository settings, require explicit user intent.
- A request such as “push this”, “open a PR”, or “publish these changes” counts as explicit authorisation for the corresponding operation.
- Never force-push, merge, delete remote branches, publish releases, or modify production resources unless explicitly requested.
- Prefer non-destructive API operations.
- Use dry-run or preview modes when supported and materially useful.
- Report the exact remote write actions performed.

## Pre-approved routine commands

Codex may run the following commands without asking for additional approval when
they are relevant to the task and used non-destructively.

These workflow approvals do not override sandbox, filesystem, network, host, scheduler, or platform permission requirements.

### Repository inspection

- `git status`
- `git diff`
- `git diff --staged`
- `git log`
- `git show`
- `git branch --show-current`
- `git remote -v`
- `git fetch`
- `git ls-files`
- `git grep`

### GitHub inspection

Long-running monitoring commands must use bounded waits or provide periodic progress updates, and should stop when the requested terminal condition is reached.

- `gh repo view`
- `gh pr list`
- `gh pr view`
- `gh pr diff`
- `gh pr checks`
- `gh issue list`
- `gh issue view`
- `gh run list`
- `gh run view`
- `gh run watch`
- `gh api` when used with a read-only `GET` request

### Local validation and inspection

- repository-defined formatting, linting, type-checking, testing, and build commands;
- commands that inspect files, dependencies, tool versions, processes, storage,
  scheduler state, or accelerator state;
- read-only package-manager commands such as listing, auditing, or showing
  dependency metadata.

These approvals do not extend to commands that modify remote state, rewrite Git
history, delete data, install system-wide software, alter credentials, or modify
production resources.

## Restricted actions

Ask first unless the operation is clearly and explicitly authorized within the current task’s scope.

- force-pushing or rewriting published history;
- deleting remote branches, releases, repositories, cloud resources, or production data;
- merging pull requests;
- publishing packages or releases;
- Editing a checked-in configuration file within an authorized code change is distinct from applying that configuration to a live environment. Applying live settings, secrets, access policies, DNS, deployment variables, database configuration, or repository settings requires explicit authorization.
- performing major dependency upgrades;
- changing access controls, credentials, secrets, billing, or repository settings;
- executing database migrations against shared or production systems;
- broad destructive filesystem operations.

## Validation

- Discover the repository’s validation workflow from its documentation, configuration files, CI definitions, Makefile, task runner, and local `AGENTS.md`.
- Run the smallest relevant validation set first.
- For source changes, run applicable formatting, linting, type-checking, tests, and builds when feasible.
- Prefer targeted tests during development, followed by broader checks when warranted.
- Do not claim a check passed unless it was run successfully.
- Report skipped checks and why they were skipped.
- Address errors and warnings introduced by the change.
- Distinguish pre-existing failures from failures caused by the change.
- Avoid running unusually expensive integration, benchmark, GPU, cluster, full-dataset, or external-service workflows unless requested or clearly necessary.
- Do not consume substantial cloud, HPC, accelerator, or paid resources without explicit justification.

## Reading documents and data

- Inspect enough of the source to understand its structure, scope, and relevance.
- Read the complete relevant section when the task depends on exact wording or complete coverage.
- For large files, use targeted search, indexing, sampling, streaming, or programmatic inspection rather than loading the entire file unnecessarily.
- Before finalising, verify important claims against the source.
- Distinguish direct quotations, close paraphrases, interpretations, and assumptions.
- Never invent content not present in the source.
- Preserve wording and style when requested.
- When transforming structured data, retain schema, identifiers, units, and missing-value semantics unless instructed otherwise.

## Scientific and data-processing work

- Preserve input data unless explicitly instructed otherwise.
- Write derived outputs to distinct, clearly named paths.
- Record relevant versions, parameters, database versions, and random seeds in the requested output, an existing project provenance mechanism, or the final report. Do not introduce a new tracked provenance file unless the task requires it.
- Validate file formats and representative records before processing a full dataset.
- For large datasets, test workflows on a small representative subset first when feasible.
- Avoid silently dropping malformed records; count and report them.
- Preserve sample identifiers and provenance.
- Do not commit large datasets, credentials, intermediate outputs, or generated binaries unless repository policy explicitly requires it.
- When parallelising, respect scheduler allocations and derive thread or process counts from the execution environment where appropriate.
- On shared systems, avoid uncontrolled parallelism, excessive temporary storage, or unnecessary duplicate data.
- Report assumptions affecting biological, statistical, or computational interpretation.

## Secrets and sensitive data

- Never print secrets, tokens, private keys, passwords, credentials, or confidential values to terminal output.
- Do not ask users to paste secrets into chat or source files.
- Avoid commands that may expose secrets, including broad environment dumps or indiscriminate reads of credential directories.
- Prefer existing authenticated CLIs, credential stores, environment injection, or secret managers.
- Redact sensitive strings in displayed output.
- Do not commit secrets or sensitive local configuration.
- Before committing, inspect the diff for accidental credentials, private data, or large generated files.
- Treat human, clinical, unpublished, embargoed, and identifiable research data as sensitive.

## Task continuity

For substantial or multi-turn implementation tasks, use `.agent/CONTINUITY.md` as a concise handoff record.

- Read it before continuing an existing multi-turn task.
- Create it only when the task is sufficiently complex that state may otherwise be lost.
- Do not create or update it for trivial, read-only, or single-step tasks.
- Treat it as working state rather than user-facing project documentation.
- Do not commit it unless the repository already tracks it or the user requests it.
- Update it only when there is a meaningful change in goal, plan, decision, progress, discovery, or outcome.
- Create the parent `.agent/` directory when needed. Do not modify `.gitignore` solely for this file unless requested; use local exclusion where appropriate. A repository-specific `AGENTS.md` may define another continuity location.


### Recommended format

Use only the sections that are relevant:

- `[PLANS]`: intended steps and acceptance criteria;
- `[DECISIONS]`: material decisions and their rationale;
- `[PROGRESS]`: implementation progress or changes in direction;
- `[DISCOVERIES]`: important behaviour, performance findings, bugs, or trade-offs supported by concise evidence;
- `[OUTCOMES]`: completed work, remaining limitations, and lessons learned.

### Anti-drift and anti-bloat rules

- Record facts, not transcripts or raw logs.
- Include an ISO timestamp and provenance tag such as `[USER]`, `[CODE]`, `[TOOL]`, or `[ASSUMPTION]` for material entries.
- Mark unknown facts as `UNCONFIRMED`; never guess.
- When facts change, explicitly supersede the earlier entry.
- Keep the file short and high-signal.
- Compress older detail into milestone bullets when sections become long.
- Do not duplicate information already maintained authoritatively elsewhere in the repository.

## Definition of done

A task is complete when:

- the requested outcome and acceptance criteria are satisfied;
- the implementation is limited to the intended scope;
- relevant validation has been run, or skipped checks are identified with reasons;
- errors introduced by the change have been addressed;
- pre-existing failures are clearly distinguished;
- affected documentation is updated where necessary;
- sensitive data and unrelated user changes remain protected;
- `.agent/CONTINUITY.md` is updated when the task materially affects long-running state;
- the final response summarises:
  - what changed;
  - where it changed;
  - what validation was run;
  - any remaining limitations or follow-up work.
