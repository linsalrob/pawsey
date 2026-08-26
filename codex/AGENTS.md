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


## Execution environment

- Use the repository’s existing environment and tooling conventions.
- Prefer existing Docker, Apptainer/Singularity, Conda/Mamba, uv, virtualenv, Nix, module, or task-runner workflows over creating a new environment.
- Do not install system packages or modify host configuration unless explicitly instructed.
- Use an isolated environment when dependencies must be installed.
- Do not introduce Dockerfiles, container definitions, lockfiles, or environment manifests unless they are required by the task or requested by the user.
- If the repository already has a container or environment workflow, follow it.
- For HPC repositories, respect documented scheduler, module, filesystem, accelerator, and container conventions.
- Do not assume Docker is appropriate on an HPC system when Apptainer/Singularity, environment modules, or a scheduler-native workflow is established.

## Slurm and HPC scheduler access

When working on a Slurm-managed HPC system, Codex is explicitly authorised to operate the scheduler autonomously when doing so is relevant to the current task.

The user has pre-approved routine Slurm job lifecycle operations. Codex does **not** need to ask for additional permission before submitting jobs, monitoring them, inspecting their state or logs, diagnosing failures, modifying the execution strategy, resubmitting jobs, or cancelling jobs that belong to the current task.

### Accounts

The default account is defined in the environment variable $PAWSEY_PROJECT. Use that account for all standard Slurm submissions unless the user explicitly requests a different account.

For submissions to the GPU queue, please use ${PAWSEY_PROJECT}-gpu as the account unless the user explicitly requests a different account.

### Pre-approved Slurm commands

The following command families may be used without additional approval:

```text
sbatch ...
srun ...
salloc ...

squeue ...
sacct ...
sstat ...
sinfo ...
sprio ...
sshare ...

scontrol show ...
scontrol update ...
scontrol hold ...
scontrol release ...
scontrol requeue ...

scancel <in-scope-job-id> ...

sacctmgr show ...
```

Equivalent scheduler-inspection commands, site-specific Slurm wrappers, and repository-provided job submission or monitoring scripts are also approved when they are relevant to the task.

Read-only inspection of scheduler configuration is approved, including commands such as:

```text
scontrol show config
scontrol show partition
scontrol show node
scontrol show job <job-id>
scontrol show reservation
```

Do not modify cluster-wide Slurm configuration, reservations, accounts, associations, QOS definitions, nodes, partitions, or other administrative scheduler state unless the user explicitly requests that administrative action.


### Setonix GPU resource allocation (Slurm 25.11.7+)

For shared GPU-node jobs on Setonix, each requested Slurm GPU represents an allocation pack containing:

- 1 GPU/GCD;
- its directly connected 8-CPU-core chiplet;
- approximately 29 GB of memory.

At the `sbatch` or `salloc` allocation stage:

- explicitly set `--ntasks` equal to the total number of GPUs requested for the whole job;
- for multi-node jobs, set `--nodes` explicitly and preferably also set `--ntasks-per-node` equal to the number of GPUs requested per node;
- prefer `--gres=gpu:<GPUS_PER_NODE>` or `--gpus-per-node=<GPUS_PER_NODE>` for requesting GPUs;
- do not use `#SBATCH --gpus-per-task` for multi-node allocations because it does not reliably allocate the corresponding CPU chiplets;
- when requesting an entire GPU node, use `--exclusive`.

The allocation-stage task count describes GPU allocation packs and may differ from the task count used later by `srun`. Configure the actual task layout, GPUs per task, CPU cores per task, and GPU binding in `srun`.

Example for two nodes with three GPUs per node:

    #SBATCH --nodes=2
    #SBATCH --gres=gpu:3
    #SBATCH --ntasks=6
    #SBATCH --ntasks-per-node=3
    #SBATCH --account=${PAWSEY_PROJECT}-gpu

The explicit `--ntasks` setting is optional for a single-node, single-GPU job, where one task is the default, and for jobs using `--exclusive`. Nevertheless, specifying it explicitly is preferred for consistency.

If an allocation omits the required task count, Slurm may reserve the GPUs and memory but only one 8-core chiplet per node. Subsequent `srun` steps may then fail with “More processors requested than permitted” or related completion errors.

### Autonomous job submission

Codex may autonomously:

* create and edit Slurm submission scripts;
* choose appropriate partitions, accounts, QOS settings, walltimes, memory, CPU counts, GPU counts, constraints, and other resource requests based on the task and available cluster configuration;
* inspect `sinfo`, existing project scripts, documentation, previous jobs, and scheduler state to determine appropriate resource requests;
* submit individual jobs and job arrays;
* create job dependencies using `--dependency`;
* submit preprocessing, analysis, validation, aggregation, and post-processing jobs;
* use `srun` within allocations when appropriate;
* submit additional jobs in response to results from earlier jobs;
* resubmit failed or incomplete jobs after diagnosing and correcting the cause;
* adjust requested time, memory, CPUs, GPUs, partitions, array sizes, or related Slurm parameters when evidence indicates that the original request was inappropriate;
* use scheduler-native parallelism rather than launching uncontrolled processes on login nodes.

Submitting jobs is considered a normal execution action, not an external deployment or production operation.

### Jobs requiring Codex analysis after completion

If subsequent work depends on Codex inspecting, interpreting, validating, or reasoning about the output of a Slurm job, submit the job using:

```bash
sbatch --wait job.slurm
```

The `--wait` option causes `sbatch` to remain attached until the Slurm job reaches a terminal state.

Use this pattern when the workflow is:

1. submit a computational job;
2. wait for it to finish;
3. inspect stdout, stderr, exit status, and generated files;
4. interpret the scientific or computational result;
5. decide what analysis should happen next.

For example:

```bash
sbatch --wait run_vamb.slurm

### Slurm job arrays: do not throttle

When submitting Slurm job arrays, submit the complete array without an
artificial concurrency limit unless the user explicitly requests one or the
cluster requires one.

Prefer:

    #SBATCH --array=1-1000

rather than:

    #SBATCH --array=1-1000%10

Do not add `%N` array throttles merely to reduce scheduler load, be conservative,
limit simultaneous jobs, or avoid using too many compute nodes.

The Slurm scheduler is responsible for deciding how many array elements can run
simultaneously based on:

- available compute resources;
- partition limits;
- account and QOS limits;
- scheduling priority;
- fair-share policy;
- per-user or per-account job limits;
- node availability;
- other site scheduler policies.

Submitting the full array allows Slurm to start as many elements as the cluster
can appropriately accommodate.

If an existing submission script contains an array throttle such as:

    #SBATCH --array=1-500%20

and there is no documented scientific, technical, or cluster-policy reason for
the throttle, Codex may remove the `%20` and submit:

    #SBATCH --array=1-500

without asking for additional permission.

Likewise, when constructing an array dynamically, do not introduce a throttle:

    sbatch --array=1-"$N" job.slurm

rather than:

    sbatch --array=1-"$N"%20 job.slurm

Array throttling is appropriate only when there is a concrete reason outside
ordinary scheduler resource management, for example:

- the user explicitly requests a concurrency limit;
- a cluster policy requires a particular limit;
- jobs access an external service with a rate limit;
- jobs contend for a shared resource that is not managed by Slurm;
- excessive simultaneous filesystem or database access would cause a known
  technical problem;
- the workflow itself imposes a concurrency constraint.

When such a constraint exists, document why the throttle is necessary rather
than applying one by default.


## After the job completes:
cat logs/vamb.out
cat logs/vamb.err
ls -lh results/
```

Long queueing and execution times are normal on the cluster. Do not treat a long-running `sbatch --wait` command as a failure merely because it takes substantial time to return.

After the job completes:

- inspect the Slurm stdout and stderr files;
- inspect the expected output files;
- verify that the job actually completed successfully;
- continue the analysis without waiting for additional user instruction if the next step follows naturally from the scientific objective;
- if the job failed, diagnose the failure, modify the job or analysis as appropriate, and resubmit it.

Do not repeatedly poll `squeue` in a tight loop when `sbatch --wait` provides the required behaviour.

## Jobs with predetermined downstream steps

If the next computational step is already known and does not require Codex to inspect or interpret the intermediate result, do not wait for each job individually.

Instead, capture the Slurm job ID using:

```bash
job1=$(sbatch --parsable job1.slurm)
```

Then submit downstream jobs using Slurm dependencies.

For example:

```bash
job1=$(sbatch --parsable assemble.slurm)

job2=$(sbatch --parsable \
    --dependency=afterok:$job1 \
    map_reads.slurm)

job3=$(sbatch --parsable \
    --dependency=afterok:$job2 \
    analyse_mapping.slurm)

echo "Submitted pipeline:"
echo "  assembly: $job1"
echo "  mapping:  $job2"
echo "  analysis: $job3"
```

Prefer:

```bash
--dependency=afterok:$jobid
```

when the downstream job should run only if the preceding job completed successfully.

Use other Slurm dependency types only when their semantics are intentionally required.

### Choosing between `--wait` and `--parsable`

Use:

```bash
sbatch --wait job.slurm
```

when Codex must regain control after the job and examine its output before deciding what to do next.

Use:

```bash
jobid=$(sbatch --parsable job.slurm)
```

when the workflow after that job is already known and can be expressed as Slurm job dependencies.

As a general rule:

```text
Does Codex need to inspect the result before deciding the next step?

    YES  -> sbatch --wait
    NO   -> sbatch --parsable + Slurm dependencies
```

Prefer Slurm dependencies for deterministic computational pipelines and reserve Codex intervention for points where interpretation, validation, troubleshooting, or scientific decision-making is required.

### Mixed workflows

A workflow may combine both approaches.

For example, several deterministic preprocessing steps can be chained using dependencies, followed by a final job that Codex waits for:

```bash
job1=$(sbatch --parsable preprocess.slurm)

job2=$(sbatch --parsable \
    --dependency=afterok:$job1 \
    assemble.slurm)

sbatch --wait \
    --dependency=afterok:$job2 \
    summarise.slurm
```

After `summarise.slurm` completes, inspect its outputs and determine the next analysis based on the results.

This is preferred over making Codex wait unnecessarily between deterministic stages.

### General Slurm behaviour

- Never run substantial compute workloads directly on login nodes.
- Record submitted job IDs where they may be useful for diagnostics.
- Use Slurm dependencies rather than manually waiting between jobs whose relationship is known in advance.
- Use `sbatch --wait` when Codex itself is the decision point between stages.
- Do not abandon an analysis merely because a Slurm job spends a long time queued or running.
- When a job fails, inspect its state, stdout, stderr, resource usage, and exit code before deciding how to proceed.
- Avoid rapid repeated calls to `squeue`, `sacct`, or other Slurm controller commands.
- Continue autonomously through routine computational steps where doing so is safe and consistent with the scientific objective.


### Monitoring jobs to completion

When a task requires results from Slurm jobs, Codex is authorised and expected to monitor those jobs until they reach the state necessary to continue the task.

Codex may repeatedly inspect:

```text
squeue
sacct
sstat
scontrol show job
```

and may inspect job stdout/stderr, application logs, output files, accounting information, and resource utilisation while jobs execute.

Monitoring may continue across long-running jobs. Prefer bounded polling intervals rather than tight loops. For example, polling scheduler state every 30–120 seconds is reasonable for ordinary jobs, with longer intervals for long-running workloads.

Do not abandon an analysis merely because the submitted computation does not finish immediately. If completion of an in-scope job is required for the requested task, continue monitoring it and proceed with downstream analysis when it finishes.

When useful, Codex may use commands such as:

```bash
while squeue -h -j "$jobid" | grep -q .; do
    sleep 60
done
```

or equivalent bounded monitoring mechanisms.

For job arrays, Codex may monitor individual array elements, identify failed elements, and selectively resubmit or requeue them.

### Diagnosing and recovering failed jobs

Codex may autonomously investigate jobs in states including:

```text
FAILED
CANCELLED
TIMEOUT
OUT_OF_MEMORY
NODE_FAIL
PREEMPTED
BOOT_FAIL
DEADLINE
REVOKED
SPECIAL_EXIT
```

as well as jobs that remain pending unexpectedly.

Diagnosis may include:

* reading stdout and stderr;
* inspecting `sacct` exit codes and state;
* inspecting `scontrol show job`;
* examining `ReqMem`, `MaxRSS`, elapsed time, CPU utilisation, GPU utilisation, and related accounting information;
* determining why a job is pending;
* checking partition, QOS, reservation, dependency, account, node, or resource constraints;
* checking application logs and intermediate outputs;
* running small diagnostic or test jobs.

After identifying a likely cause, Codex may make an in-scope correction and resubmit the job without requesting permission.

Examples include:

* increasing memory after an out-of-memory failure;
* increasing walltime after a timeout;
* reducing memory or CPU requests when excessive requests prevent scheduling;
* changing to an appropriate partition;
* correcting malformed Slurm directives;
* correcting command-line arguments or environment setup;
* repairing job dependencies;
* splitting workloads into arrays;
* changing array concurrency;
* retrying jobs affected by transient node or filesystem failures.

Prefer evidence-based adjustments rather than repeatedly increasing resources without diagnosis.

### Cancelling, holding, releasing, and requeuing jobs

Codex may use:

```text
scancel
scontrol hold
scontrol release
scontrol requeue
```

without additional permission for jobs that were submitted as part of the current task or are otherwise clearly identified as belonging to the current task.

This includes cancelling jobs that:

* are known to be incorrect;
* are superseded by a corrected submission;
* are wasting resources because of an identified error;
* are stuck or no longer needed;
* must be replaced with different resource requests.

Do **not** cancel, hold, release, requeue, or otherwise alter unrelated jobs belonging to the user or other users.

Avoid broad commands such as:

```text
scancel -u "$USER"
scancel --state=PENDING
```

unless the user explicitly requests that broader action and its scope is clear.

### Job arrays and dependencies

Codex is authorised to use Slurm arrays and dependency graphs where they improve efficiency or correctness.

This includes:

```text
--array=...
--dependency=afterok:...
--dependency=afterany:...
--dependency=afternotok:...
--dependency=singleton
```

Codex may determine sensible array concurrency limits based on cluster policy, dataset size, available resources, and existing scheduler load.

Where one computation produces input required by another, prefer scheduler dependencies over manual waiting when practical.

### Resource selection

Before launching substantial workloads, inspect enough of the environment to make a reasonable resource request.

Relevant inspection may include:

```text
sinfo
squeue
sacct
scontrol show partition
scontrol show node
module avail
module list
nvidia-smi
rocm-smi
```

as applicable to the system.

Use existing project or cluster conventions where available.

Derive application thread counts from Slurm allocations where possible, for example:

```bash
$SLURM_CPUS_PER_TASK
$SLURM_CPUS_ON_NODE
```

Do not spawn computational workloads on login/head nodes when those workloads should run through Slurm.

Small filesystem inspection, script preparation, metadata processing, compilation where locally appropriate, scheduler inspection, and similar lightweight operations may be performed on the login node subject to site policy.

### Compute-budget autonomy

When the user's requested scientific or computational objective inherently requires HPC computation, submission of proportionate Slurm workloads is considered explicitly authorised by this file.

Codex may therefore consume the CPU, memory, GPU, filesystem, and scheduler resources reasonably necessary to complete the task without requesting separate approval for each job.

However:

* use resources proportionately to the scientific or computational objective;
* prefer a small representative test before launching a very large workflow when feasible;
* avoid obviously wasteful duplicate computation;
* reuse valid existing outputs where appropriate;
* respect project allocations, storage quotas, scheduler limits, and site policies;
* do not intentionally monopolise shared resources;
* do not submit unrelated speculative workloads merely because capacity is available.

If a workflow would represent an extraordinary escalation beyond the apparent scope of the task—for example, consuming essentially an entire allocation, launching an exceptionally large multi-day campaign, or creating significant external financial cost—ask first unless the user has explicitly requested that scale of computation.

### Long-running task continuity

Slurm jobs are often asynchronous. A submitted job should not be treated as completion of the task when its output is required for subsequent work.

For an active task, Codex should normally follow the full lifecycle:

```text
inspect inputs
→ prepare workflow
→ submit job
→ record job ID
→ monitor scheduler
→ inspect logs/results
→ diagnose failures if any
→ resubmit/requeue if necessary
→ validate completed outputs
→ perform downstream analysis
→ report results
```

Record important job IDs, parameters, output paths, failures, and recovery decisions in `.agent/CONTINUITY.md` when the work is substantial enough to require continuity tracking.

### Reporting

In the final response, report material scheduler activity concisely, including:

* important jobs or arrays submitted;
* whether they completed successfully;
* meaningful failures and corrections;
* relevant resource or performance observations;
* output locations;
* any jobs deliberately left running, if applicable.

Raw scheduler polling output does not need to be reproduced unless it is relevant to understanding a problem or result.


## Dependencies

- Prefer existing dependencies and standard-library functionality.
- Add or upgrade dependencies only when justified by the task.
- Before changing dependencies, inspect the repository’s package-management and lockfile conventions.
- Use the project’s established package manager.
- Update and preserve the appropriate lockfile when dependency changes require it.
- Avoid major-version upgrades or broad dependency refreshes unless requested.
- Avoid replacing one dependency ecosystem with another without explicit justification.
- Explain newly added runtime dependencies in the final summary.
- Seaborn is a pre-approved dependency for Python scientific visualisation and
  may be installed temporarily into an isolated environment whenever required
  for an in-scope analysis.

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
- Never force-push, merge, delete remote branches, publish releases, or modify production resources unless explicitly requested.
- Prefer non-destructive API operations.
- Use dry-run or preview modes when supported and materially useful.
- Report the exact remote write actions performed.

## ChatGPT collaboration

ChatGPT is used as a higher-level scientific and strategic collaborator.

When a task reaches a point where scientific interpretation, strategic
direction, literature knowledge, or a consequential analytical choice
would materially benefit from ChatGPT input:

1. Do not stop unnecessarily if there is an obvious safe next step.
2. Summarize the current state clearly.
3. Record:
   - the objective;
   - work completed;
   - important findings;
   - relevant commits/files/results;
   - the decision or question;
   - your recommended answer or next step.
4. Post this as a comment to the project's coordination GitHub issue,
   prefixed `CODEX → CHATGPT`.
5. Continue any independent work that does not depend on the answer.

When a comment prefixed `CHATGPT → CODEX` is provided, treat it as
high-level guidance, reconcile it with the repository state and
AGENTS.md, and continue the work.

## Pre-approved routine commands

Codex may run the following commands without asking for additional approval when
they are relevant to the task and used non-destructively.

These workflow approvals do not override sandbox, filesystem, network, host, scheduler, or platform permission requirements.

### Repository inspection

The user has approved these command families for routine work:

```text
git add <explicit-in-scope-paths>
git branch --show-current
git commit -m <descriptive-message>
git diff
git diff --cached --check
git diff --cached --stat
git diff --check
git fetch origin
git fetch origin <relevant-branch>
git grep
git log
git ls-files
git pull --ff-only
git push
git push -u origin <current-task-branch>
git remote -v
git show
git status
git switch -c <task-branch>
git switch main
```

Deleting a local task branch is approved only after the user states that its pull request
has been merged and identifies or clearly implies that branch. This does not authorize
remote branch deletion:

```text
git branch -d <merged-local-task-branch>
```

`git push` and `git push -u origin <current-task-branch>` are pre-approved when
the current user request clearly implies publication, pull-request preparation,
CI validation, or updating an existing remote task branch. They are not approved
for pushing unrelated local commits, pushing directly to a protected/default
branch, changing remotes, deleting remote branches, or force-pushing.

### GitHub inspection

Long-running monitoring commands must use bounded waits or provide periodic progress updates, and should stop when the requested terminal condition is reached.

When the user asks to create, update, monitor, or address feedback on a pull request, the
following authenticated GitHub CLI operations are approved:

```text
gh repo view
gh pr list
gh pr diff
gh issue list
gh issue view

gh --version
gh auth status
gh pr create ...
gh pr view <current-pr> ...
gh pr checks <current-pr> ...
gh pr comment <current-pr> --body "@codex review"
gh run list --repo linsalrob/contigger ...
gh run view <relevant-run> ...
gh run watch <relevant-run> ...
gh api graphql ...
gh api repos/linsalrob/contigger/actions/workflows
gh api repos/linsalrob/contigger/actions/runs...
```

Treat `gh` failures caused by restricted sandbox networking separately from invalid, missing, or expired GitHub credentials.
GitHub network failures inside a restricted sandbox may be retried with the environment's required network elevation.
When network access is unavailable, report that authentication could not be verified from the sandbox; do not conclude that the user's credentials are invalid.


When appropriate, retry `gh` outside the restricted sandbox or request network permission rather than asking the user to reauthenticate immediately.

The GraphQL approval includes reading pull-request review threads and resolving a thread
only after its actionable feedback has actually been addressed and the user has asked the
agent to resolve outstanding review comments. Read-only Actions API calls must remain
scoped to `linsalrob/contigger`. Posting `@codex review` is approved only for requesting a
re-review of a pull request the user asked the agent to monitor.

The following repository-local GitHub helper scripts have also been approved with Python
3.11:

```text
python3.11 ~/.codex/plugins/cache/openai-curated-remote/github/*/skills/gh-fix-ci/scripts/inspect_pr_checks.py ...
python3.11 ~/.codex/plugins/cache/openai-curated-remote/github/*/skills/gh-address-comments/scripts/fetch_comments.py ...
```

If the user has asked Codex to address PR review feedback, and a review thread
has been addressed by the pushed change, Codex is pre-approved to mark that
specific thread as resolved. Do not resolve informational, disputed, ambiguous,
or unaddressed threads.

## Node, npm, and npx commands approved

When the repository already uses Node tooling, the following are approved for
routine repository-scoped work:

```text
node --version
npm --version
npx --version
npm test
npm run <repository-defined-script>
npm exec -- <repository-defined-tool> ...
npx --yes <repository-defined-tool> ...
```

`npx` and `npm exec` are approved only when the tool is already declared in the
repository configuration, lockfile, or documented project workflow, or when the
user explicitly asks for that tool.

`npx` and `npm exec` may use network access only when required to install or
run the repository-declared tool, and only within the current task scope.

These approvals do not authorize global package installation, major dependency
upgrades, publishing packages, changing credentials, running unreviewed remote
install scripts, or executing arbitrary packages unrelated to the task.


## Read-only inspection commands approved

Routine repository-scoped inspection is approved, including:

```text
rg ...
rg --files ...
sed -n ...
find <repository-or-established-environment-path> ...
ls ...
wc ...
column ...
gzip -cd ...
sha256sum ...
```

Reads of `~/.codex/AGENTS.md` and installed skill instructions are approved when needed to
follow current agent policy. These approvals do not permit broad credential-directory
reads, environment dumps, or output that exposes tokens or secrets.

## File editing and publication boundaries

- Repository edits explicitly requested by the user are approved through patch-style edits.
- Stage only named files that belong to the requested change.
- Temporary files under `/tmp` may be created for test outputs and pull-request bodies.
- Local planning or approval files must remain untracked unless the user explicitly asks
  for them to be committed.
- Opening and updating a pull request is approved when explicitly requested.


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
- Never use `git reset --hard`, `git clean -fd`, force-push, rebase published history, or
  broad recursive deletion under this standing approval.

## Validation

- Discover the repository’s validation workflow from its documentation, configuration files, CI definitions, Makefile, task runner, and local `AGENTS.md`.
- Run the smallest relevant validation set first.
- For source changes, run applicable formatting, linting, type-checking, tests, and builds when feasible.
- Prefer targeted tests during development, followed by broader checks when warranted.
- Do not claim a check passed unless it was run successfully.
- Report skipped checks and why they were skipped.
- Address errors and warnings introduced by the change.
- Distinguish pre-existing failures from failures caused by the change.
- Avoid unusually expensive integration, benchmark, GPU, cluster, full-dataset,
  or external-service workflows unless requested, clearly necessary to accomplish
  the task, or authorised by the Slurm/HPC section.
- HPC and accelerator resources used through the documented Slurm workflow are
  pre-authorised when proportionate to the requested task. Substantial paid cloud
  resources or extraordinary HPC expenditure still require explicit justification
  or user authorisation.

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

### Python figures and visualisation

When creating scientific figures or exploratory visualisations in Python, use
**Seaborn as the default plotting library**, with Matplotlib underneath where
needed for lower-level control.

- Prefer Seaborn for statistical plots, distributions, categorical plots,
  regression plots, heatmaps, and general publication-quality scientific
  visualisation.
- Use Matplotlib directly when Seaborn does not provide the required plot type
  or when precise low-level figure control is necessary.
- Prefer clear, publication-quality figures with:
  - readable axis labels and units;
  - appropriate legends;
  - sensible figure dimensions;
  - consistent typography;
  - colour palettes that remain interpretable and, where practical,
    colour-blind accessible;
  - minimal unnecessary visual clutter.
- Do not use arbitrary or decorative styling when a simpler scientific
  presentation communicates the result more clearly.
- Save figures at appropriate resolution and in formats suitable for the
  requested use. Prefer vector formats such as PDF or SVG for line art and
  plots when practical, and high-resolution PNG for raster output.

If Seaborn is not installed, Codex is explicitly authorised to install it
temporarily without asking for additional permission.

Prefer installation into the currently active project, Conda, virtualenv, or
other isolated Python environment, for example:

    python -m pip install seaborn

or, when using Conda/Mamba:

    mamba install seaborn

Do not install Seaborn system-wide or modify the host operating system merely
to create a figure.

If no suitable Python environment exists, Codex may create a temporary isolated
environment, install Seaborn and its required plotting dependencies there, and
use that environment for the analysis. Temporary environments need not be
committed to the repository.

Installing Seaborn for an in-scope analysis is considered a routine,
pre-approved dependency action and does not require separate user approval.

When writing reusable analysis scripts or notebooks, import Seaborn explicitly,
normally as:

    import seaborn as sns

and use Seaborn by default unless there is a technical or scientific reason to
choose another visualisation library.




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
