# AlphaFold 3 on Setonix (MI250X / ROCm)

AlphaFold 3 runs on Setonix's AMD MI250X GPUs through George Bouras's port of the
[`sokrypton/alphafold3`](https://github.com/sokrypton/alphafold3) JAX fork
(`alphafold3_open` 3.1.4, jax 0.10.2 with AMD's ROCm plugin, `rocm/7.2.4` module).
George's own instructions (`af3jax/INSTRUCTIONS.md`, 2 Oct 2026) ship in his `af3jax.zip` bundle, which
is **not** in this repository: it is his unreleased work. Ask George for it. This page records how we
installed and used the port, and what we learned doing so.

The bundle holds the wrapper and helper scripts, the container recipe, the instructions, and George's
validation inputs and results. It does not hold the Python environment (`stockenv/`, ~4 GB), the patched
AlphaFold tree, the optimisation kit (`ubm/`) or any weights. Those are copied from George's installation
(below), which also has the same `scripts/` directory.

Licences: the code is a fork of AlphaFold 3 (CC BY-NC-SA 4.0, non-commercial). The AlphaFold 3 parameters
(`af3.bin.zst`) are under Google DeepMind's terms of use: keep them in a private folder, never in git.

## 1. Install

The environment comes from George's tree, `/scratch/pawsey1018/gbouras/af3jax-setonix` (readable by
`pawsey1018` members). Copy it with a job on the `copy` partition:

```bash
#!/bin/bash
#SBATCH --job-name=af3-copy
#SBATCH --account=pawsey1018
#SBATCH --partition=copy
#SBATCH --time=02:00:00
#SBATCH --output=af3-copy-%j.out
SRC=/scratch/pawsey1018/gbouras/af3jax-setonix
DST=/scratch/pawsey1018/$USER/af3jax
mkdir -p "$DST"
# --no-times: give the copies today's date. rsync -a keeps the source mtimes, and /scratch purges
# files 21 days after their date, so a plain -a copy disappears on the source tree's schedule.
for d in stockenv alphafold scripts ubm; do rsync -a --no-times "$SRC/$d" "$DST/"; done
du -sh "$DST"; find "$DST" | wc -l          # ~3.8 GB, ~42,400 files
```

Three `ubm/.git/objects/pack/*.promisor` files are unreadable and are skipped; nothing at runtime needs them.

**Then repoint the editable `opt_core` install** at your copy, or it keeps loading kernels from George's tree
and breaks when that is purged:

```bash
F=$DST/stockenv/lib/python3.12/site-packages/__editable___opt_core_0_5_228_0_finder.py
sed -i "s#/scratch/pawsey1018/gbouras/af3jax-setonix/ubm/#$DST/ubm/#g" "$F"
grep -c gbouras "$F"     # expect 0
```

The remaining references to George's path (`pyvenv.cfg`, `direct_url.json`, the default `W=` in
`af3jax_predict.sh`) are not used at runtime once `AF3JAX_W` is set.

Where to install:
- `/software/projects/pawsey1018/$USER` is the documented, unpurged location, but in Oct 2026 it returned
  `Disk quota exceeded` (the project quota, not the per-user one). We installed on `/scratch` instead.
- A `/scratch` copy is purged 21 days after its date. Re-run the copy (or move to `/software` once there is
  room) before then.

## 2. Parameters

```bash
mkdir -p /scratch/pawsey1018/$USER/af3_params && chmod 700 /scratch/pawsey1018/$USER/af3_params
cp af3.bin.zst /scratch/pawsey1018/$USER/af3_params/ && chmod 600 /scratch/pawsey1018/$USER/af3_params/af3.bin.zst
export AF3JAX_MODEL_DIR=/scratch/pawsey1018/$USER/af3_params
```

Without `--model_dir` / `AF3JAX_MODEL_DIR` the wrapper silently uses the **OpenFold3-preview2** weights.
Those give different scores from AlphaFold 3. Always set it, and check that the first log line says
`weights=af3(...)`.

## 3. Inputs

Standard AlphaFold 3 JSON, one file per folder, `"templates": []`. The wrapper always passes
`--norun_data_pipeline` (no HMMER here), so MSAs must be in the JSON:

- `unpairedMsa` / `pairedMsa` inline, or `unpairedMsaPath` / `pairedMsaPath`.
  **Relative `*MsaPath` values resolve against the JSON file's folder, not the working directory**
  (`alphafold3/common/folding_input.py`, `_read_file`). Use absolute paths.
- `-- --use_msa_server` makes the fork fetch MSAs from `api.colabfold.com`. That **sends your sequences to
  a public server**: never use it for unpublished sequences. Pre-compute the MSAs locally (ColabFold/MMseqs2
  against the local databases) and pass them in.
- `"unpairedMsa": "", "pairedMsa": ""` runs MSA-free (fast, much less accurate).

## 4. Run

Always inside a Slurm job on a GPU node. A whole node (`--exclusive`) is the validated configuration:

```bash
#!/bin/bash
#SBATCH --account=pawsey1018-gpu
#SBATCH --partition=gpu            # gpu-dev for tests (max 4 h, one running job per user)
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --time=04:00:00
export AF3JAX_W=/scratch/pawsey1018/$USER/af3jax
export AF3JAX_MODEL_DIR=/scratch/pawsey1018/$USER/af3_params
export AF3JAX_CACHE=/scratch/pawsey1018/$USER/af3jax-cache/stock1   # one cache per regime
bash $AF3JAX_W/scripts/af3jax_predict.sh --input_dir in/my_complex --output_dir out --regime stock1 --gcd 0
```

- **8 independent inputs per node:** start eight wrappers in the background with `--gcd 0..7`, then `wait`.
  GPU time is charged per GCD, so this avoids paying for idle GCDs.
- **Regimes** (`--regime`): `stock1` = the plain AF3 network on one GCD; `A` (auto default up to 3,584
  tokens) adds flash triangle attention, a bf16 diffusion sampler and diffusion hoisting (~1.5–3× faster);
  `B` (3,585–4,480) adds memory levers; `C` / `stock8` shard across 8 GCDs. The plain network does not fit
  one GCD above about 3,584 tokens.
- The wrapper always passes `--flash_attention_implementation=xla`; don't set `XLA_FLAGS`,
  `HIP_LAUNCH_BLOCKING`, `AMD_SERIALIZE_*` or `TOKAMAX_ROCM_TRITON` yourself.
- Padding: the wrapper pads to a multiple of 128 tokens (`--bucket` to override), not AF3's default
  bucket list. Timings are therefore not directly comparable with stock AF3 runs elsewhere.
- **Exit status is not success.** Check that `<name>/<name>_summary_confidences.json` exists and parses.
- The first log line records the decision: `tokens~… bucket=… regime=… weights=…`. Keep it.

### Validate before trusting results

The speed regimes were validated with the OpenFold3 weights; with the AF3 parameters, run a known input both
ways (`--regime stock1` on GCD 0, default on GCD 1) and compare with
`$AF3JAX_W/stockenv/bin/python $AF3JAX_W/scripts/perf_cmp.py OUT plain fast --conf` (section 6 of
George's INSTRUCTIONS.md). If results must match an earlier AF3 run (other hardware or version), rerun a control set
spanning the full score range with the same seeds and MSAs, and pick **one** regime for the whole campaign.

Measured on Setonix with the AF3 parameters (2 Oct 2026, one 288-residue heterodimer, seed 1, 10 recycles):
ipTM 0.93 under both `stock1` and `A` (0.94 on a Gadi V100 with AF3 3.0.1); AF3 inference 88 s (`stock1`) vs
57 s (`A`); wall time per pair including wrapper start-up 142 s vs 112 s.

## 5. Things to know

- **Maintenance:** all Setonix partitions are reserved 6 Oct 08:00 – 3 Nov 08:00 2026. Slurm won't start a
  job that would overlap it. Re-run the validation check afterwards: a ROCm update can break the stack.
- **Login nodes:** editing and submitting only; anything that runs the stack's Python goes in a job.
- **Troubleshooting:** section 9 of George's `INSTRUCTIONS.md` (OOM → let `--regime auto` choose; segfault at
  first execution → `--serialise block`; slow start → check Lustre read speed).
