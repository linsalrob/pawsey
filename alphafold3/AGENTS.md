# AGENTS.md — AlphaFold 3 on Setonix

Operating notes for an agent installing or running AlphaFold 3 on Setonix's MI250X GPUs. `README.md` in
this directory has the commands; this file is what the commands do not tell you. The nearest repository or
subdirectory `AGENTS.md` and any explicit user instruction take precedence over this file.

## Before you run anything

**Verify the installation actually exists.** `/scratch` purges files 21 days after their date, so an
install can vanish between sessions. The wrapper checks for its own files and prints `MISSING: ...`, but
check before you queue work:

```bash
W=${AF3JAX_W:?}; for f in stockenv/bin/python alphafold/run_alphafold.py scripts/af3jax_predict.sh \
  scripts/perf_launch.py scripts/rowpair_launch.py ubm/common/opt_core; do
  [ -e "$W/$f" ] && echo "OK      $f" || echo "MISSING $f"; done
grep -c gbouras $W/stockenv/lib/python3.12/site-packages/__editable___opt_core_*_finder.py   # must be 0 in a private copy
[ -s "${AF3JAX_MODEL_DIR:?}/af3.bin.zst" ] && echo "OK      af3.bin.zst"
```

If the install has gone, rebuild it with the copy job in `README.md` §1. **Use `rsync --no-times`**
(otherwise the copies keep the source's old dates and are purged early), then repoint `opt_core`.

## Rules that cost a day if you learn them the hard way

- **Set `AF3JAX_MODEL_DIR`.** If it is unset, the wrapper uses the OpenFold3 weights *without an error*.
  The first log line must say `weights=af3(...)`.
- **Never pass `--use_msa_server` for sequences that aren't public.** It sends them to
  `api.colabfold.com`. The wrapper runs with `--norun_data_pipeline`, so MSAs must already be in the JSON.
- **Relative `unpairedMsaPath` values resolve against the JSON file's folder**, not the working
  directory. Write absolute paths when the JSON lives somewhere temporary.
- **Exit 0 is not success.** A run counts only if `<name>_summary_confidences.json` exists and parses. Never
  replace that check with `&& echo ok`.
- **Interface score:** for a two-chain complex, the A–B interface is `chain_pair_iptm[0][1]` in the
  summary JSON. The top-level `iptm` is a whole-complex value.
- **Choose one regime per campaign and record it.** `stock1` (plain network), `A` (flash triangle attention +
  bf16 sampler + hoisting) and `B`/`C` give slightly different numbers and very different timings. Do not
  mix regimes inside a set of scores you will compare. Note that `--regime auto` changes regime with input size.
- **Validate against a known answer first.** Run one input end to end before queueing anything. For a
  campaign that must match earlier results, run a control set spanning the full score range (not just
  high scorers) with identical seeds and MSAs.
- **Don't set `XLA_FLAGS`, `HIP_LAUNCH_BLOCKING`, `AMD_SERIALIZE_*` or `TOKAMAX_ROCM_TRITON`.** The
  wrapper sets them; overriding them brings back the crashes it works around.
- **Give each regime its own `AF3JAX_CACHE`**, on persistent storage you can write to. George's default
  cache isn't writable by other users, and the wrapper then quietly recompiles every run.

## Scheduling

- Whole node (`--exclusive`, account `pawsey1018-gpu`), one wrapper per GCD (`--gcd 0..7`) for one-GCD
  regimes. Shared-node single-GCD allocations have not been validated with this wrapper.
- `gpu-dev` is limited to 4 h and one running job per user. Use it for smoke tests and control sets.
- Inputs above ~3,584 tokens don't fit the plain network on one GCD and need `stock8` (8 GCDs). Run those as
  a separate job.
- Per-call wrapper start-up (copying and patching the tree, loading weights) is ~55 s (measured). It matters for
  small inputs.
- Check for maintenance reservations (`scontrol show reservation`). After a ROCm or system update, rerun
  the stock-vs-fast check before trusting results.

## Provenance to record with every result set

Wrapper first log line (bucket, regime, levers, gemm, weights), `alphafold3_open` version (3.1.4),
`rocm` module, seeds, MSA source, and the install path. When reporting, distinguish what was run and
checked from what is inferred.
