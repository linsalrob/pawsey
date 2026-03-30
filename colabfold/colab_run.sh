

module swap pawseyenv/2025.08 pawseyenv/2024.05

module load singularity/4.1.0-nohost

 
# define some useful environment variables for the container
# this would need to be updated for a users workflow
export containerImage=/scratch/$PAWSEY_PROJECT/$USER/colabfold/colabfold_rocm6_cpuTF.sif


export TF_FORCE_UNIFIED_MEMORY="1"
export XLA_PYTHON_CLIENT_MEM_FRACTION="4.0"
export XLA_PYTHON_CLIENT_ALLOCATOR="platform"
export TF_FORCE_GPU_ALLOW_GROWTH="true"





IDX=$(printf "%03d" "${SLURM_ARRAY_TASK_ID}")

INDIR="arc_protein_msas/$IDX"
OUTDIR="arc_protein_structure/$IDX"
mkdir -p "$OUTDIR"

for formatted_input in $(seq 1 20); do

    done_file="$OUTDIR/$formatted_input.done"
    in_tar="$INDIR/batch${formatted_input}.tar.gz"
    in_dir="$INDIR/batch${formatted_input}"
    out_dir="$OUTDIR/batch${formatted_input}"
    out_tar="$OUTDIR/batch${formatted_input}.tar.gz"

    if [ -f "$done_file" ]; then
        echo "batch ${formatted_input} already processed. Skipping."
        continue
    fi

    echo "▶ Processing batch ${formatted_input}"

    # Clean up any half-finished state from previous crash
    rm -rf "$in_dir" 

    # Extract inputs
    mkdir -p "$in_dir"
    echo "▶ untarring ${in_tar} into ${in_dir}"
    tar -xzf "$in_tar" -C "$INDIR"
    
    rm "${in_dir}/uniref_plus_colabfolddb.a3m"
    # Run colabfold
    echo "▶ running ${in_dir}"
    singularity exec --rocm "$containerImage" \
        colabfold_batch --num-models 1 "$in_dir" "$out_dir"

    echo "batch ${formatted_input} processed, archiving output"

    # Archive outputs atomically
    tar -czf "$out_tar" -C "$OUTDIR" "batch${formatted_input}" && rm -rf "$in_dir" "$out_dir"

    # Mark as done LAST
    touch "$done_file"

    echo "✔ batch ${formatted_input} complete"

done
