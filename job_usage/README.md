# job_usage: per-job efficiency reports, and a SPANK plugin to automate them

`job_usage.sh` is Pawsey's job report script, copied from
`/software/pawsey/tools/pawseytools/bin/job_usage.sh`. One local change:
JSON output writes values below 1 (which `bc` prints as `.5`) as `0.5`
instead of `null`. Given a finished job
ID, it reports CPU, memory and walltime efficiency and the service units the
job was charged:

```bash
./job_usage.sh 53333612                 # text report with recommendations
./job_usage.sh 53333612 --format json   # or csv; --quiet drops the advice
```

The SPANK plugin in this directory runs it automatically when a job ends, so
users can ask for the report at submission time:

```bash
sbatch --job-usage job.slurm                    # text report appended to slurm-<id>.out
sbatch --job-usage=json job.slurm               # JSON instead
sbatch --job-usage-output=usage/%j.csv --job-usage=csv job.slurm
```

or in the script itself, `#SBATCH --job-usage`.

## How it works

| File | Role |
|------|------|
| `job_usage_spank.c` | SPANK plugin. Registers `--job-usage[=text\|csv\|json\|off]` and `--job-usage-output=PATH` for `sbatch`, `salloc` and `srun`, and validates them at submission. |
| `job_usage_epilog.sh` | Helper the plugin starts from the job epilog. |
| `job_usage.sh` | The report itself. |
| `sbatch-usage` | User-level wrapper giving the same options without the plugin (see below). |
| `plugstack.conf.d/job_usage.conf` | Example SPANK configuration line. |

1. At submission, Slurm forwards the options to the job's epilog.
2. In `slurm_spank_job_epilog` (run by `slurmd` as root on every node of
   the job), the plugin double-forks a detached process, drops to the job
   owner's uid/gid/groups with a clean environment, and execs
   `job_usage_epilog.sh`. The epilog returns straight away, and it returns
   success even if something goes wrong, so a reporting problem can never
   delay node cleanup or drain a node.
3. The helper reads the job record with `scontrol` while the controller
   still holds it. It exits on every node except the batch host (or the
   first node of an `salloc` allocation).
4. `sacct` only shows the final state some seconds after the epilog runs,
   and `job_usage.sh` refuses to report on a job it does not see as
   finished. The helper therefore polls `sacct` every 10 s, for up to
   `wait=` seconds.
5. It runs `job_usage.sh` as the user and appends the report to the job's
   `StdOut` file. Without one, it writes `WorkDir/job_usage-<id>.txt`; with
   `--job-usage-output`, it writes to that path (`%j` = job id, `%u` = user;
   a relative path is relative to the job's working directory).

## Building and installing (needs a Slurm administrator)

SPANK plugins are loaded by `slurmd` and by the client commands from
`plugstack.conf`, which is cluster configuration. A user cannot enable this
on their own; it has to be installed by the site.

```bash
make                       # builds job_usage.so against /usr/include/slurm
make install BINDIR=/software/pawsey/tools/pawseytools/bin PLUGINDIR=/usr/lib64/slurm
cp plugstack.conf.d/job_usage.conf /etc/slurm/plugstack.conf.d/
```

`/etc/slurm/plugstack.conf` on Setonix already has
`include /etc/slurm/plugstack.conf.d/*.conf`; the directory just does not
exist yet. The `.so` and the `.conf` must be present on the login nodes
(so the client commands know the options) and on every compute node (so the
epilog runs). Rebuild whenever Slurm is upgraded: a SPANK plugin must be
built against the headers of the running version (currently 25.11.8).

Plugin arguments in `plugstack.conf`:

| Argument | Default | Meaning |
|---|---|---|
| `helper=PATH` | `$(BINDIR)/job_usage_epilog.sh` | helper to exec |
| `script=PATH` | `$(BINDIR)/job_usage.sh` | report script |
| `wait=SECONDS` | `300` | how long to wait for `sacct` to finalise the job |
| `default=on` | off | report for every job; users opt out with `--job-usage=off` |

The line is marked `optional`, so if the plugin is missing or fails to
load on a node, jobs still run.

## Testing without root

The client side can be tested with a private copy of the configuration:

```bash
mkdir -p /tmp/jt && cp /etc/slurm/*.conf /tmp/jt/
grep -vi '^PlugStackConfig' /etc/slurm/slurm.conf > /tmp/jt/slurm.conf
echo "PlugStackConfig=/tmp/jt/plugstack.conf" >> /tmp/jt/slurm.conf
echo "required $PWD/job_usage.so" > /tmp/jt/plugstack.conf
SLURM_CONF=/tmp/jt/slurm.conf sbatch --help | grep -A3 job-usage
SLURM_CONF=/tmp/jt/slurm.conf sbatch --job-usage=xml --wrap=true   # rejected
```

The epilog half needs `slurmd`, but the helper can be run by hand on any
finished job:

```bash
./job_usage_epilog.sh --jobid <id> --any-host --output /tmp/report-%j.txt
```

## Without the plugin: `sbatch-usage`

`sbatch-usage` gives users the same options with no administrator
involvement. It accepts every `sbatch` option, plus `--job-usage[=FORMAT]`
and `--job-usage-output=PATH`:

```bash
alias sbatch=/path/to/job_usage/sbatch-usage     # optional, e.g. in ~/.bashrc
sbatch --job-usage job.slurm
sbatch --job-usage=csv --array=1-100 job.slurm
```

`sbatch` rejects unknown `#SBATCH` lines, so inside a script use
`#JOB_USAGE` instead:

```bash
#SBATCH --time=2:00:00
#JOB_USAGE --job-usage=json --job-usage-output=usage/%j.json
```

The wrapper submits the job, then a follow-on job
(`--dependency=afterany:<id>`, 1 core, 1 GB, about 10 minutes) that runs
`job_usage_epilog.sh`. That costs about 0.01 SU per job. Its account is the
job's own account with any `-gpu` suffix removed, and it runs in the default
partition. Add options for it with `JOB_USAGE_SBATCH_ARGS`.

- A single job's report is appended to its stdout file.
- For an array, every element is reported in one file,
  `<WorkDir>/job_usage-<array id>.<txt|csv|json>` (the stdout path of a
  pending array is not known element by element). There is one follow-on
  job per array, not one per element.
- With `--wait`, no extra job is submitted: the report is written from the
  wrapper once `sbatch` returns.
- `--parsable` output is unchanged; the wrapper's own messages go to stderr.

As with `sbatch`, options go before the script name: anything after it (or
after `--`) is passed to the script untouched. To find where the script
starts, the wrapper reads which options take a value from `sbatch --help`.

Difference from the plugin: `salloc` and `srun` are not covered.
