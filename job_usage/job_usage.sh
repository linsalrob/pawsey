#!/bin/bash -l
# Usage: ./job_usage.sh <jobid> [--format text|csv|json] [--no-csv-header] [--quiet]

usage() {
    echo "Usage: $0 <jobid> [--format text|csv|json] [--no-csv-header] [--quiet]"
}

OUTPUT_FORMAT="text"
CSV_INCLUDE_HEADER=1
QUIET_MODE=0
JOBID=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --format|-f)
            shift
            if [[ -z "$1" ]]; then
                echo "Error: --format requires a value (text|csv|json)." >&2
                usage
                exit 1
            fi
            OUTPUT_FORMAT=$(echo "$1" | tr '[:upper:]' '[:lower:]')
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        --no-csv-header)
            CSV_INCLUDE_HEADER=0
            ;;
        --quiet|-q)
            QUIET_MODE=1
            ;;
        --*)
            echo "Error: Unknown option '$1'." >&2
            usage
            exit 1
            ;;
        *)
            if [[ -z "$JOBID" ]]; then
                JOBID="$1"
            else
                echo "Error: Unexpected argument '$1'." >&2
                usage
                exit 1
            fi
            ;;
    esac
    shift
done

if [[ -z "$JOBID" ]]; then
    usage
    exit 1
fi

if [[ ! "$OUTPUT_FORMAT" =~ ^(text|csv|json)$ ]]; then
    echo "Error: Unsupported format '$OUTPUT_FORMAT'. Use text, csv, or json." >&2
    exit 1
fi

#CHECK
export LC_NUMERIC=C

# --- Helper functions --- #

# Helper: Convert time string (D-HH:MM:SS) to total hours (supports optional days)
time_to_hours() {
    local t=$1 d=0 h=0 m=0 s=0
    [[ $t == *-* ]] && { d=${t%%-*}; t=${t#*-}; }
    IFS=':' read -r h m s <<< "$t"
    echo "scale=4; ($d*24)+$h+($m/60)+($s/3600)" | bc -l
}

# Helper: Format time string (D-HH:MM:SS) to human-readable format ---
format_time() {
    local t=$1
    local days=0 hours=0 mins=0 secs=0
    if [[ "$t" == *-* ]]; then
        days=${t%%-*}
        t=${t#*-}
    fi
    IFS=: read -r hours mins secs <<< "$t"
    if [[ -z $secs ]]; then
        secs=$mins; mins=$hours; hours=0
    fi
    local out=""
    (( days > 0 )) && out+="${days}d"
    (( hours > 0 )) && out+="${hours}h"
    (( mins > 0 )) && out+="${mins}m"
    (( secs > 0 )) && out+="${secs}s"
    [[ -z $out ]] && out="0s"
    echo "$out"
}

# Helper: Convert D-HH:MM:SS, H:MM:SS, M:SS(.ms) or seconds -> seconds
time_str_to_secs() {
    local t="$1"
    local d=0
    t=$(echo "$t" | tr ',' '.' | tr -d '[:space:]')
    [[ $t == *-* ]] && { d=${t%%-*}; t=${t#*-}; }
    IFS=':' read -r a b c <<< "$t"
    local base_secs
    if [ -z "$b" ]; then
        # plain seconds
        base_secs=$(awk -v x="$a" 'BEGIN { printf "%.3f", x }')
    elif [ -z "$c" ]; then
        # MM:SS(.ms)
        base_secs=$(awk -F: '{ printf "%.3f", ($1*60) + $2 }' <<< "$t")
    else
        # HH:MM:SS(.ms)
        base_secs=$(awk -F: '{ printf "%.3f", ($1*3600) + ($2*60) + $3 }' <<< "$t")
    fi
    awk -v days="$d" -v secs="$base_secs" 'BEGIN { printf "%.3f", (days*86400) + secs }'
}

# Helper: Convert memory string to GB
convert_to_gb() {
    local mem_str="$1"
    local default_unit="${2:-gb}"   # optional default unit (default: GB)

    # Extract numeric value and unit (handles cases like 1000Kc, 10.5G, etc.)
    local mem_value mem_unit
    mem_value=$(echo "$mem_str" | grep -oE '^[0-9]+(\.[0-9]+)?' | head -1)
    mem_unit=$(echo "$mem_str" | sed 's/^[0-9.]*//; s/[cn]$//' | tr '[:upper:]' '[:lower:]')

    # Default to provided default unit if empty
    [[ -z "$mem_unit" ]] && mem_unit="$default_unit"

    # Convert to GB
    case "$mem_unit" in
        b)
            echo "$(echo "scale=6; $mem_value / 1024 / 1024 / 1024" | bc -l)"
            ;;
        k|kb)
            echo "$(echo "scale=6; $mem_value / 1024 / 1024" | bc -l)"
            ;;
        m|mb)
            echo "$(echo "scale=6; $mem_value / 1024" | bc -l)"
            ;;
        g|gb)
            printf "%.6f" "$mem_value"
            ;;
        t|tb)
            echo "$(echo "scale=6; $mem_value * 1024" | bc -l)"
            ;;
        *)
            # Fallback - assume GB
            echo "$mem_value"
            echo "Warning: Unknown memory unit '$mem_unit', assuming GB" >&2
            ;;
    esac
}

# Helper: Convert ReqMem (supports per-CPU "c" / per-node "n") into total GB.
reqmem_to_total_gb() {
    local reqmem_str="$1"
    local req_cpus="$2"
    local req_nodes="$3"

    reqmem_str=$(echo "$reqmem_str" | tr -d '[:space:]')
    if [ -z "$reqmem_str" ]; then
        echo "0"
        return
    fi

    local mem_value mem_suffix mem_unit scope base_gb multiplier
    mem_value=$(echo "$reqmem_str" | grep -oE '^[0-9]+(\.[0-9]+)?' | head -1)
    if [ -z "$mem_value" ]; then
        echo "0"
        return
    fi

    mem_suffix=$(echo "$reqmem_str" | sed 's/^[0-9.]*//' | tr '[:upper:]' '[:lower:]')
    scope=""
    if [[ "$mem_suffix" =~ [cn]$ ]]; then
        scope="${mem_suffix: -1}"
        mem_suffix="${mem_suffix%?}"
    fi

    # Slurm ReqMem defaults to MB when no unit is given.
    mem_unit="$mem_suffix"
    [[ -z "$mem_unit" ]] && mem_unit="mb"
    base_gb=$(convert_to_gb "${mem_value}${mem_unit}" "mb")

    multiplier=1
    case "$scope" in
        c)
            if [[ "$req_cpus" =~ ^[0-9]+$ ]] && [ "$req_cpus" -gt 0 ]; then
                multiplier="$req_cpus"
            fi
            ;;
        n)
            if [[ "$req_nodes" =~ ^[0-9]+$ ]] && [ "$req_nodes" -gt 0 ]; then
                multiplier="$req_nodes"
            fi
            ;;
    esac

    echo "$(echo "scale=6; $base_gb * $multiplier" | bc -l)"
}

# Helper: Format memory display with appropriate units
format_memory() {
    local mem_gb=$1
    if (( $(echo "$mem_gb < 0.99" | bc -l) )); then
        # Sub-GB values: show MB with at most 2 decimal places.
        mem_mb=$(echo "scale=4; $mem_gb * 1024" | bc)
        awk -v mb="$mem_mb" 'BEGIN { printf "%.2fMB", mb }' | sed -E 's/\.?0+MB$/MB/'
    elif (( $(echo "$mem_gb >= 1024" | bc -l) )); then
        # 1 TB or more: show TB with up to 2 decimal places.
        mem_tb=$(echo "scale=4; $mem_gb / 1024" | bc)
        awk -v tb="$mem_tb" 'BEGIN { printf "%.2fTB", tb }' | sed -E 's/(\.[0-9]*[1-9])0+TB$/\1TB/; s/\.00TB$/TB/'
    else
        # 1 GB or more: show GB with up to 2 decimal places.
        awk -v gb="$mem_gb" 'BEGIN { printf "%.2fGB", gb }' | sed -E 's/(\.[0-9]*[1-9])0+GB$/\1GB/; s/\.00GB$/GB/'
    fi
}

# Helper: format walltime suggestion in hours or minutes
format_walltime_suggest() {
    local hours=$1
    if (( $(echo "$hours < 1" | bc -l) )); then
        local mins=$(awk -v h="$hours" 'BEGIN { printf "%d", h * 60 + 0.5 }')
        echo "${mins} minutes"
    else
        echo "${hours} hours"
    fi
}

# Helper: extract TRES value (e.g. gres/gpu=2) from a TRES string
get_tres_val() { echo "$1" | grep -oP "$2" | head -1 || echo "0"; }

# CSV-safe quoted cell
csv_escape() {
    local s="$1"
    s=${s//\"/\"\"}
    printf '"%s"' "$s"
}

# Basic JSON string escape
json_escape() {
    local s="$1"
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    s=${s//$'\r'/\\r}
    s=${s//$'\t'/\\t}
    printf '%s' "$s"
}

# Print a JSON number literal, or null if non-numeric/empty.
json_num_or_null() {
    local v="$1"
    if [[ "$v" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
        printf '%s' "$v"
    else
        printf 'null'
    fi
}

# --- Job data --- #
# Fetch job data from sacct
FIELDS="JobID,Account,State,ExitCode,Partition,ReqCPUS,AllocCPUS,TotalCPU,ReqMem,AllocTRES,Timelimit,Elapsed,NNodes,AveRSS,NTasks,CPUtime,CPUTimeRAW,Submit,Start,End"

# Force standard timestamp formatting so Submit/Start/End include date and time.
JOB_DATA=$(SLURM_TIME_FORMAT=standard sacct -n -j "$JOBID" --format="$FIELDS" -P)

# Check if job ID was found
if [ -z "$JOB_DATA" ]; then
    echo "Error: Job ${JOBID} not found."
    exit 1
fi

# Read job data lines into an array
IFS=$'\n' read -rd '' -a LINES <<< "$JOB_DATA"

# Select parent job row explicitly (JobID exactly equals requested JOBID).
job_line=""
for line in "${LINES[@]}"; do
    [ -z "$line" ] && continue
    IFS='|' read -r line_jobid _ <<< "$line"
    if [ "$line_jobid" = "$JOBID" ]; then
        job_line="$line"
        break
    fi
done
[ -z "$job_line" ] && job_line="${LINES[0]}"

IFS='|' read -r jobid account state exitcode partition reqcpus alloccpus totalcpu reqmem alloctres timelimit elapsed nnodes averss ntasks cputime cputimeraw submit_time start_time end_time <<< "$job_line"
# Normalize missing sacct timestamps
for ts_var in submit_time start_time end_time; do
    ts_val="${!ts_var}"
    if [ -z "$ts_val" ] || [[ "$ts_val" =~ ^(Unknown|N/A|None|0)$ ]]; then
        printf -v "$ts_var" '%s' "N/A"
    else
        # Standardize "YYYY-MM-DDTHH:MM:SS" to "YYYY-MM-DD HH:MM:SS" for display.
        ts_val="${ts_val/T/ }"
        printf -v "$ts_var" '%s' "$ts_val"
    fi
done

# Make sure job has actually run before we start making assumptions about it
if [[ ! "$state" =~ ^(COMPLETED|FAILED|CANCELLED|OUT_OF_MEM|TIMEOUT) ]]; then
  echo "Job is not yet in a finished state. It is $state."
  exit 1
fi

# Determine number of GCDs requested 
ngpus_alloc=$(get_tres_val "$alloctres" 'gres/gpu=\K[0-9]+')
# Print value of 0 if there was no gpu request to avoid confusion with empty/unknown values.
ngpus_alloc=${ngpus_alloc:-0}

# Defensive check for number of nodes requested
if [ -z "$nnodes" ]; then
    echo "Warning: nnodes is empty, defaulting to 1. Please check upstream job data." >&2
    nnodes=1
fi

# Clean exit code
exitcode=${exitcode%%:*}

# --- CPU efficiency (common to all partitions) --- #
# Convert elapsed and timelimit to hours
elapsed_hours=$(time_to_hours "$elapsed")
walltime_hours=$(time_to_hours "$timelimit")

# elapsed seconds from elapsed_hours
elapsed_secs=$(echo "$elapsed_hours * 3600" | bc -l)

# Convert sacct TotalCPU (e.g. "00:40:58" or "40:57.651") to seconds
totalcpu_secs=$(time_str_to_secs "$totalcpu")

# Divide AllocCPUS by 2 to get actual CPU cores allocated (since AllocCPUS counts hyperthreads)
alloccpus_no_hyperthreading=$((alloccpus / 2))

# CPU time available (core-walltime); prefer CPUTimeRAW from sacct for seff parity
if [[ "$cputimeraw" =~ ^[0-9]+([.][0-9]+)?$ ]] && (( $(echo "$cputimeraw > 0" | bc -l) )); then
    cpu_time_available_secs="$cputimeraw"
else
    cpu_time_available_secs=$(echo "$alloccpus * $elapsed_secs" | bc -l)
fi

# Calculate CPU efficiency
# Defensive fallbacks if something missing
if [ -z "$totalcpu_secs" ] || [ -z "$cpu_time_available_secs" ]; then
    cpu_efficiency="0.00"
else
    # Use TotalCPU as numerator; denominator is core-walltime (CPUTimeRAW / CPUTime)
    # prevent division by zero
    if (( $(echo "$cpu_time_available_secs > 0" | bc -l) )); then
        # Keep higher precision and multiply first to avoid early truncation.
        cpu_efficiency=$(echo "scale=8; ($totalcpu_secs * 100.0) / $cpu_time_available_secs" | bc -l)
    else
        cpu_efficiency="0.00"
    fi
fi
# -------------------------------- #

# --- Memory usage and efficiency --- #
# AveRSS is the average memory across tasks within a step.
# Multiply AveRSS × NTasks to get total job memory (matches seff methodology).
max_memory_all_gb="0"
for line in "${LINES[@]}"; do
    [ -z "$line" ] && continue
    IFS='|' read -r _ _ _ _ _ _ _ _ _ _ _ _ _ line_averss line_ntasks _ _ _ _ _ <<< "$line"
    line_averss=$(echo "$line_averss" | tr -d '[:space:]')

    # Ignore empty/non-numeric placeholders returned by sacct.
    if ! echo "$line_averss" | grep -Eq '^[0-9]+([.][0-9]+)?[[:alpha:]]*[cn]?$'; then
        continue
    fi

    line_averss_gb=$(convert_to_gb "$line_averss" "b")

    # Scale by number of tasks to get total memory for this step
    if [[ "$line_ntasks" =~ ^[0-9]+$ ]] && [ "$line_ntasks" -gt 0 ]; then
        line_total_gb=$(echo "scale=6; $line_averss_gb * $line_ntasks" | bc -l)
    else
        line_total_gb="$line_averss_gb"
    fi

    if (( $(echo "$line_total_gb > $max_memory_all_gb" | bc -l) )); then
        max_memory_all_gb="$line_total_gb"
    fi
done

# Requested memory (reqmem)
reqcpus_for_mem="$reqcpus"
if ! [[ "$reqcpus_for_mem" =~ ^[0-9]+$ ]] || [ "$reqcpus_for_mem" -le 0 ]; then
    reqcpus_for_mem="$alloccpus"
fi
mem_requested_gb=$(reqmem_to_total_gb "$reqmem" "$reqcpus_for_mem" "$nnodes")

# Used memory (AveRSS)
mem_used_gb="$max_memory_all_gb"

# Calculate memory efficiency as percentage
memory_efficiency=$(awk -v used="$mem_used_gb" -v req="$mem_requested_gb" \
'BEGIN { if (req>0) { pct=(used/req)*100; if (pct>100) pct=100; printf "%.2f", pct } else print "N/A" }')

# -------------------------------- #

# --- Service Unit Calculation --- #
# Detect partition type and set charge rates and node resources
case "$partition" in
    *gpu*)
        partition_type="gpu"
        charge_rate=512
        node_gpus=8
        ;;
    *highmem*)
        partition_type="highmem"
        charge_rate=128
        node_mem_gb=980
        node_cores=128
        ;;
    *copy*)
        partition_type="copy"
        charge_rate=0
        node_mem_gb=115
        node_cores=64
        ;;    
    *)
        partition_type="cpu"
        charge_rate=128
        node_mem_gb=230
        node_cores=128
        ;;
esac

# Calculate service units (SUs) based on partition type
if [[ "$partition_type" == "gpu" ]]; then
    gpu_proportion=$(awk -v g="$ngpus_alloc" -v nn="$nnodes" -v n="$node_gpus" 'BEGIN { if (n>0) printf "%.6f", (g/nn)/n; else print 0 }')
    service_units=$(awk -v rate="$charge_rate" -v prop="$gpu_proportion" -v n="$nnodes" -v hrs="$elapsed_hours" \
    'BEGIN { printf "%.4f", rate * prop * n * hrs }')
else

# Calculate core and mem proportions, determine which is higher to use for SU calculation

    cores_proportion=$(awk -v a="$alloccpus_no_hyperthreading" -v nn="$nnodes" -v n="$node_cores" 'BEGIN { printf "%.6f", (a/nn)/n }')
    mem_proportion=$(awk -v u="$mem_requested_gb" -v nn="$nnodes" -v n="$node_mem_gb" 'BEGIN { p=(u/nn)/n; if (p>1) p=1; printf "%.6f", p }')
    max_proportion=$(awk -v c="$cores_proportion" -v m="$mem_proportion" 'BEGIN { if (c>m) printf "%.6f", c; else printf "%.6f", m }')

    # --- SU calculation ---
    service_units=$(awk -v rate="$charge_rate" -v maxp="$max_proportion" -v n="$nnodes" -v hrs="$elapsed_hours" \
        'BEGIN { printf "%.4f", rate * maxp * n * hrs }')
fi
#######
format_elapsed() {
    local t="$1"
    local d=0 h=0 m=0 s=0

    # Handle optional day prefix in D-HH:MM:SS.
    if [[ "$t" == *-* ]]; then
        d=${t%%-*}
        t=${t#*-}
    fi

    IFS=':' read -r h m s <<< "$t"

    # If it's missing seconds (e.g., "03:11"), treat it as mm:ss.
    if [[ -z "$s" ]]; then
        s="$m"
        m="$h"
        h=0
    fi

    # For display, fold days into hours so printf always gets integers.
    h=$((10#$h + (10#$d * 24)))
    m=$((10#$m))
    s=$((10#$s))

    printf "%02d:%02d:%02d" "$h" "$m" "$s"
}

# Walltime efficiency check
walltime_efficiency=$(awk -v e="$elapsed_hours" -v w="$walltime_hours" 'BEGIN { if (w>0) printf "%.2f", (e/w)*100; else print "0" }')

# Common display/machine fields
current_date=$(date '+%Y-%m-%d %H:%M:%S')
cpu_eff_fmt=$(printf "%.2f%%" "$cpu_efficiency")
cpu_time_requested_fmt=$(format_elapsed "${cputime%%.*}")
cpu_time_used_fmt=$(format_elapsed "${totalcpu%%.*}")
mem_requested_fmt=$(format_memory "$mem_requested_gb")
mem_used_fmt=$(format_memory "$mem_used_gb")
service_units_fmt=$(printf "%.4f" "$service_units")
service_units_text_fmt=$(printf "%.2f" "$service_units")
cpu_efficiency_num=$(printf "%.2f" "$cpu_efficiency")
gcds_requested="$ngpus_alloc"

if [ "$memory_efficiency" = "N/A" ]; then
    memory_eff_fmt="N/A"
else
    memory_eff_fmt="${memory_efficiency}%"
fi
if [ "$memory_efficiency" = "N/A" ]; then
    memory_efficiency_num=""
else
    memory_efficiency_num="$memory_efficiency"
fi


if [ "$OUTPUT_FORMAT" = "csv" ]; then
    if [ "$CSV_INCLUDE_HEADER" -eq 1 ]; then
        echo "generated_at,job_id,project,partition,exit_status,job_state,nodes_requested,gcds_requested,ncpus_requested,ncpus_allocated,ncpus_allocated_raw,cpu_time_available,cpu_time_available_s,cpu_time_used,cpu_time_used_s,memory_requested,memory_requested_gb,memory_used,memory_used_gb,walltime_requested,walltime_used,walltime_requested_h,walltime_used_h,walltime_efficiency_pct,cpu_efficiency_pct,memory_efficiency_pct,service_units,job_submitted,job_started,job_ended"
    fi
    printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" \
        "$(csv_escape "$current_date")" \
        "$(csv_escape "$jobid")" \
        "$(csv_escape "$account")" \
        "$(csv_escape "$partition")" \
        "$(csv_escape "$exitcode")" \
        "$(csv_escape "$state")" \
        "$(csv_escape "$nnodes")" \
        "$(csv_escape "$gcds_requested")" \
        "$(csv_escape "$reqcpus")" \
        "$(csv_escape "$alloccpus_no_hyperthreading")" \
        "$(csv_escape "$alloccpus")" \
        "$(csv_escape "$cpu_time_requested_fmt")" \
        "$(csv_escape "$cpu_time_available_secs")" \
        "$(csv_escape "$cpu_time_used_fmt")" \
        "$(csv_escape "$totalcpu_secs")" \
        "$(csv_escape "$mem_requested_fmt")" \
        "$(csv_escape "$mem_requested_gb")" \
        "$(csv_escape "$mem_used_fmt")" \
        "$(csv_escape "$mem_used_gb")" \
        "$(csv_escape "$timelimit")" \
        "$(csv_escape "$elapsed")" \
        "$(csv_escape "$walltime_hours")" \
        "$(csv_escape "$elapsed_hours")" \
        "$(csv_escape "$walltime_efficiency")" \
        "$(csv_escape "$cpu_efficiency_num")" \
        "$(csv_escape "$memory_efficiency_num")" \
        "$(csv_escape "$service_units_fmt")" \
        "$(csv_escape "$submit_time")" \
        "$(csv_escape "$start_time")" \
        "$(csv_escape "$end_time")"
    exit 0
elif [ "$OUTPUT_FORMAT" = "json" ]; then
    cat <<EOF
{"generated_at":"$(json_escape "$current_date")","job_id":"$(json_escape "$jobid")","project":"$(json_escape "$account")","partition":"$(json_escape "$partition")","exit_status":"$(json_escape "$exitcode")","job_state":"$(json_escape "$state")","nodes_requested":$(json_num_or_null "$nnodes"),"gcds_requested":$(json_num_or_null "$gcds_requested"),"ncpus_requested":$(json_num_or_null "$reqcpus"),"ncpus_allocated":$(json_num_or_null "$alloccpus_no_hyperthreading"),"ncpus_allocated_raw":$(json_num_or_null "$alloccpus"),"cpu_time_available":"$(json_escape "$cpu_time_requested_fmt")","cpu_time_available_s":$(json_num_or_null "$cpu_time_available_secs"),"cpu_time_used":"$(json_escape "$cpu_time_used_fmt")","cpu_time_used_s":$(json_num_or_null "$totalcpu_secs"),"memory_requested":"$(json_escape "$mem_requested_fmt")","memory_requested_gb":$(json_num_or_null "$mem_requested_gb"),"memory_used":"$(json_escape "$mem_used_fmt")","memory_used_gb":$(json_num_or_null "$mem_used_gb"),"walltime_requested":"$(json_escape "$timelimit")","walltime_used":"$(json_escape "$elapsed")","walltime_requested_h":$(json_num_or_null "$walltime_hours"),"walltime_used_h":$(json_num_or_null "$elapsed_hours"),"walltime_efficiency_pct":$(json_num_or_null "$walltime_efficiency"),"cpu_efficiency_pct":$(json_num_or_null "$cpu_efficiency_num"),"memory_efficiency_pct":$(json_num_or_null "$memory_efficiency_num"),"service_units":$(json_num_or_null "$service_units_fmt"),"job_submitted":"$(json_escape "$submit_time")","job_started":"$(json_escape "$start_time")","job_ended":"$(json_escape "$end_time")"}
EOF
    exit 0
fi

# --- Text report ---
echo "======================================================================================"
printf "Usage report generated on %s:\n" "$current_date"
echo   """
JOB DETAILS
"""
printf "   Job Id:             %-23s Project:     %s\n" "$jobid" "$account"
printf "   Exit Status:        %-23s Job State:   %s\n" "$exitcode" "$state"
printf "   Job Submitted:      %-23s Job Started: %s\n" "$submit_time" "$start_time"
printf "   Job Ended:          %-23s Partition:   %s\n" "$end_time" "$partition"


echo   """
RESOURCE USAGE
"""
printf "   Nodes Requested:    %-23s GCDs Requested:  %s\n" "$nnodes" "$gcds_requested"
printf "   NCPUs Requested:    %-23s NCPUs Allocated: %s\n" "$reqcpus" "$alloccpus_no_hyperthreading"
printf "   CPU Time Available: %-23s CPU Time Used:   %s\n" "$cpu_time_requested_fmt" "$cpu_time_used_fmt"
printf "   Memory Requested:   %-23s Memory Used:     %s\n" "$mem_requested_fmt" "$mem_used_fmt"
printf "   Walltime Requested: %-23s Walltime Used:   %s\n" "$timelimit" "$elapsed"

echo   """
EFFICIENCY METRICS
"""
printf "   Memory Efficiency:  %-23s Service Units Used:  %s\n" "$memory_eff_fmt" "$service_units_text_fmt"
printf "   CPU Efficiency:     %-23s Walltime Efficiency: %s%%\n" "$cpu_eff_fmt" "$walltime_efficiency"

if [ "$QUIET_MODE" -eq 1 ]; then
    echo "======================================================================================"
    exit 0
fi

# --- Efficiency warnings and recommendations ---  #
echo "-------------------------------------------------------------------------------------"
echo "   Efficiency Analysis & Recommendations:"
echo ""

# Exit status check
if [ "$exitcode" != "0" ]; then
    echo "    JOB FAILED (Exit code: $exitcode)"
    case "$exitcode" in
        1)   echo "     General error - check job logs" ;;
        125) echo "     Job exceeded memory limit" ;;
        126) echo "     Command cannot execute" ;;
        127) echo "     Command not found" ;;
        137) echo "     Job killed (SIGKILL) - possibly out of memory" ;;
        139) echo "     Segmentation fault" ;;
        140) echo "     Job exceeded walltime limit" ;;
        *)   echo "     Check job logs for details" ;;
    esac
fi

# Memory efficiency check
if [ -n "$memory_efficiency" ] && [ "$memory_efficiency" != "N/A" ]; then
    if (( $(echo "$memory_efficiency < 10" | bc -l) )); then
        mem_suggest=$(echo "($mem_used_gb * 1.5 + 0.999)/1" | bc)
        mem_suggest_fmt=$(format_memory "$mem_suggest")
        echo "    VERY LOW MEMORY EFFICIENCY (<10%)"
        echo "   - Consider reducing memory request to ~${mem_suggest_fmt} for similar jobs"
    elif (( $(echo "$memory_efficiency < 50" | bc -l) )); then
        mem_suggest=$(echo "($mem_used_gb * 1.5 + 0.999)/1" | bc) 
        mem_suggest_fmt=$(format_memory "$mem_suggest")
        echo "    LOW MEMORY EFFICIENCY (<50%)"
        echo "   - Consider reducing memory request to ~${mem_suggest_fmt} for similar jobs"
    elif (( $(echo "$memory_efficiency < 98" | bc -l) )); then
        echo "    GOOD MEMORY EFFICIENCY (>50% and <98%)"
        echo "   - Good use of the requested memory"
    else
        echo "    VERY HIGH MEMORY EFFICIENCY (>98%)"
        echo "   - Good use of the requested memory"
        echo "   - Consider increasing memory request slightly to avoid potential out of memory job failures"
    fi
fi

# CPU efficiency check (only for CPU partition jobs)
if [[ "$partition_type" != "gpu" ]] && [ -n "$cpu_efficiency" ]; then
    if (( $(echo "$cpu_efficiency < 25" | bc) )); then
        echo "    LOW CPU EFFICIENCY (<25%)"
        echo "     - Check if job is I/O bound or waiting on resources"
        echo "     - Consider reducing number of cores requested"
        echo "     - Consider optimising parallelisation or threading"
    elif (( $(echo "$cpu_efficiency < 50" | bc) )); then
        echo "    MODERATE CPU EFFICIENCY (25-50%)"
        echo "     - Check if job is I/O bound or waiting on resources"
        echo "     - Consider reducing number of cores requested"
        echo "     - Consider optimising parallelisation or threading"
    elif (( $(echo "$cpu_efficiency < 80" | bc) )); then
        echo "    GOOD CPU EFFICIENCY (50-80%)"
        echo "     - Reasonable use of allocated CPU resources"
    elif (( $(echo "$cpu_efficiency <= 100" | bc) )); then
        echo "    VERY GOOD CPU EFFICIENCY (80-100%)"
        echo "     - Excellent use of allocated CPU resources"
    fi
fi

# Walltime efficiency check
if (( $(echo "$walltime_efficiency < 30" | bc) )); then
        walltime_suggest=$(awk -v e="$elapsed_hours" 'BEGIN { printf "%.2f", e * 1.5 }')
        echo "    VERY LOW WALLTIME USAGE (<30% of requested)"
        echo "     - Consider reducing walltime limit to around ~$(format_walltime_suggest "$walltime_suggest") for similar jobs"
    elif (( $(echo "$walltime_efficiency < 60" | bc) )); then
        walltime_suggest=$(awk -v e="$elapsed_hours" 'BEGIN { printf "%.2f", e * 1.5 }')
        echo "    LOW WALLTIME USAGE (30-60% of requested)"
        echo "     - Consider reducing walltime limit to around ~$(format_walltime_suggest "$walltime_suggest") for similar jobs"
    elif (( $(echo "$walltime_efficiency < 80" | bc) )); then
        walltime_suggest=$(awk -v e="$elapsed_hours" 'BEGIN { printf "%.2f", e * 1.5 }')
        echo "    MODERATE WALLTIME USAGE (60-80% of requested)"
        echo "     - Check if job is waiting on resources or has long idle periods"
        echo "     - Consider reducing walltime limit to around ~$(format_walltime_suggest "$walltime_suggest") if there is consistent unused time across jobs"
    elif (( $(echo "$walltime_efficiency < 100" | bc) )); then
        echo "    GOOD WALLTIME USAGE (80-100% of requested)"
        echo "     - Reasonable use of allocated walltime"
        echo "     - Ensure walltime is sufficient to avoid job being killed for exceeding walltime limit"
fi

# Good efficiency notice
if [ "$exitcode" = "0" ] && [ -n "$memory_efficiency" ] && [ "$memory_efficiency" != "N/A" ] && [ -n "$cpu_efficiency" ]; then
    if (( $(echo "$memory_efficiency > 70 && $cpu_efficiency > 70" | bc) )); then
            echo "    Good overall resource efficiency!"
    fi
fi

echo "======================================================================================"
