#!/bin/bash
# Run by the job_usage SPANK plugin from the job epilog, as the job owner,
# detached from slurmd. Waits for sacct to record a terminal state for the
# job, then appends a job_usage.sh report to the job's stdout file (or to
# --output). Can also be run by hand to test the plugin's behaviour.
#
# Usage: job_usage_epilog.sh --jobid ID [--format text|csv|json]
#            [--output PATH] [--script job_usage.sh] [--wait SECONDS]
#            [--any-host]

JOBID=""
FORMAT="text"
OUTPUT=""
SCRIPT="$(dirname "$(readlink -f "$0")")/job_usage.sh"
WAIT=300
ANY_HOST=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --jobid)    JOBID="$2"; shift ;;
        --format)   FORMAT="$2"; shift ;;
        --output)   OUTPUT="$2"; shift ;;
        --script)   SCRIPT="$2"; shift ;;
        --wait)     WAIT="$2"; shift ;;
        --any-host) ANY_HOST=1 ;;
        *) echo "job_usage_epilog: unknown argument '$1'" >&2; exit 1 ;;
    esac
    shift
done

[[ "$JOBID" =~ ^[0-9]+$ ]] || { echo "job_usage_epilog: bad --jobid" >&2; exit 1; }
[[ "$FORMAT" =~ ^(text|csv|json)$ ]] || { echo "job_usage_epilog: bad --format" >&2; exit 1; }
[[ "$WAIT" =~ ^[0-9]+$ ]] || WAIT=300

# Read the job record now: the controller forgets it MinJobAge seconds
# after it ends, well before sacct may have the final state.
job_info=$(scontrol show job -o "$JOBID" 2>/dev/null)
field() { grep -oP "(^| )$1=\K\S*" <<< "$job_info" | head -1; }
batch_host=$(field BatchHost)
node_list=$(field NodeList)
std_out=$(field StdOut)
work_dir=$(field WorkDir)

# The epilog runs on every node of the job; report once, from the batch
# host (or the first node, for salloc/srun allocations without one).
# If the controller has already forgotten the job, report anyway.
if [[ "$ANY_HOST" -eq 0 ]]; then
    lead=$batch_host
    [[ -z "$lead" || "$lead" == "(null)" ]] && \
        lead=$(scontrol show hostnames "$node_list" 2>/dev/null | head -1)
    me=$(hostname -s)
    if [[ -n "$lead" && "${lead%%.*}" != "$me" ]]; then
        exit 0
    fi
fi

if [[ -z "$OUTPUT" ]]; then
    if [[ -n "$std_out" && "$std_out" != "(null)" && "$std_out" != /dev/* ]]; then
        OUTPUT=$std_out
    elif [[ -n "$work_dir" && "$work_dir" != "(null)" ]]; then
        OUTPUT="$work_dir/job_usage-%j.txt"
    else
        OUTPUT="$HOME/job_usage-%j.txt"
    fi
fi
OUTPUT=${OUTPUT//%j/$JOBID}
OUTPUT=${OUTPUT//%u/$USER}

# sacct lags the controller by a few seconds to minutes; poll until the
# job (not its steps) is in a terminal state.
deadline=$((SECONDS + WAIT))
while :; do
    state=$(sacct -n -X -P -j "$JOBID" --format=State 2>/dev/null | head -1)
    case "$state" in
        COMPLETED*|FAILED*|CANCELLED*|OUT_OF_ME*|TIMEOUT*) break ;;
    esac
    if (( SECONDS >= deadline )); then
        printf '\njob_usage: no report, sacct still shows job %s as %s after %ss\n' \
            "$JOBID" "${state:-unknown}" "$WAIT" >> "$OUTPUT"
        exit 1
    fi
    sleep 10
done

args=("$JOBID" --format "$FORMAT")
[[ "$FORMAT" == "text" ]] && echo >> "$OUTPUT"
"$SCRIPT" "${args[@]}" >> "$OUTPUT" 2>&1
