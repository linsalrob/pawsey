# analysis — assembly triage, rescue and variant tooling

Helper scripts used alongside the `_run.slurm` pipeline scripts in the parent
directory. They are deliberately independent of organism, sample type,
sequencing run and naming scheme.

Read `../AGENTS.md` first: it explains *why* these exist and what the results
mean. This file only covers how to invoke them.

## Conventions

**Project directory.** Every script resolves its working directory from
`PROJECT_DIR`, defaulting to the current directory. Run them from the project
root or export it:

```bash
export PROJECT_DIR=/path/to/project
```

**Sample names.** Scripts take a sample name as an argument. There is no
assumed naming pattern — a sample is whatever you called it. Array jobs read
names from a plain text file, one per line, indexed by the array task ID:

```bash
ls -1 raw/ > samples.txt
sbatch --array=1-$(wc -l < samples.txt) analysis/fastq_snapshot.slurm samples.txt snap1
python3 analysis/collect_snapshot.py snapshots/snap1
```

After more reads arrive, snapshot again and diff:

```bash
sbatch --array=1-$(wc -l < samples.txt) analysis/fastq_snapshot.slurm samples.txt snap2 raw_new
python3 analysis/collect_snapshot.py snapshots/snap2
python3 analysis/compare_snapshots.py snap1 snap2
```

**Expected layout.** Nothing is enforced, but the scripts assume roughly:

```text
raw/<sample>/*.fastq.gz     source reads, chunked as the basecaller wrote them
reads/<sample>.fastq.gz     one merged file per sample
assembly/<sample>/          autocycler output for that sample
rescue/<sample>/            candidate contigs, curated inputs, checks
snapshots/<stamp>/          read inventories
```

Override the directory names with the environment variables each script
documents in its header.

## What is here

### Read inventory

| script | purpose |
| --- | --- |
| `fastq_snapshot.slurm` | per-sample read counts, bases, lengths, quality, file manifest |
| `collect_snapshot.py` | assemble the per-sample parts into one table plus totals |
| `compare_snapshots.py` | diff two snapshots; reports added and removed files by name |
| `merge_reads.slurm` | merge chunked reads to one file per sample, refusing to duplicate |

### Assembly triage

| script | purpose |
| --- | --- |
| `summarise_assemblies.py` | recovered fraction, clusters, unitigs, resolution per sample |
| `diagnose_failures.py` | what each input assembler produced, against the consensus |

### Rescue of a failed consensus

| script | purpose |
| --- | --- |
| `extract_candidates.py` | pull the contigs of the largest rejected cluster |
| `rescue_checks.slurm` | structural concordance and mixture checks |
| `parse_dnadiff.sh` | tabulate `dnadiff` reports |
| `build_curated_input.py` | assemble a curated input set from concordant assemblies |
| `curated_rerun.slurm` | rerun compress/cluster/trim/resolve/combine, then gate |
| `gfa_topology.py` | end-to-end topology of a GFA; enumerates circular paths |
| `junction_support.slurm` | spanning-read support for competing junction hypotheses |

### Validation

| script | purpose |
| --- | --- |
| `control_vaf.slurm` | within-run error floor from a sample that assembled cleanly |
| `validate_replicons.slurm` | per-replicon depth and copy number |
| `taxonomy_check.slurm` | read-level composition, all reads and unmapped separately |
| `assess_single_assembler_draft.slurm` | circularity, coverage, contamination, cross-assembler support |

### Variants in recurring molecules

| script | purpose |
| --- | --- |
| `variant_families.py` | group assembled replicons into families, pick a reference |
| `recurring_variants.slurm` | map every carrier to the family reference and call |
| `classify_variants.py` | separate real variation from basecalling artefact |

### Environment

| script | purpose |
| --- | --- |
| `install_qc_env.slurm` | separate environment for the QC tools, so the pipeline env is untouched |
| `plassembler_subsampled.slurm` | subsample then assemble a plasmid prep |

## A note on the QC environment

The QC scripts use a separate conda environment (`assembly_qc`) rather than the
pipeline environment, so that rebuilding or extending the QC toolkit cannot
break a working assembly and annotation install. `install_qc_env.slurm` creates
it. One exception: `mash` lives in the pipeline environment, and the scripts
that need it switch environments explicitly.
