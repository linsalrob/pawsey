# Ollama on Setonix

Read the [shared guide](../README.md) first: it covers the model, storage,
matched settings, security and results. This page covers what is specific to Ollama.

Validated: Ollama **v0.40.18** on one MI250X GCD, 2026-11-27.

## Install

```bash
sbatch --account="$PAWSEY_PROJECT" --export=ALL llm/ollama/install.slurm
```

[`install.slurm`](install.slurm) runs on the `copy` partition. It downloads the
upstream `ollama-linux-amd64.tar.zst` and `ollama-linux-amd64-rocm.tar.zst`
archives for the pinned release, checks each against the SHA256 published with
the release (pinned in [`../versions.env`](../versions.env)), and extracts them into
`$LLM_ROOT/ollama-v0.40.18`. It skips the bundled NVIDIA CUDA libraries.
Extraction goes through a temporary directory, so a failed install never leaves
a prefix that looks complete. No root, systemd or install script is involved.

The ROCm archive brings Ollama's own ROCm 7.2 user-space libraries, which work
with Setonix's driver. Do **not** load a `rocm` module before running Ollama:
its library path could shadow the bundled libraries.

## Serve

```bash
# validation: import if needed, benchmark, stop
LLM_BENCH=1 sbatch --account="${PAWSEY_PROJECT}-gpu" --export=ALL llm/ollama/serve.slurm
# interactive use
sbatch --account="${PAWSEY_PROJECT}-gpu" --export=ALL --time=02:00:00 llm/ollama/serve.slurm
```

What [`serve.slurm`](serve.slurm) does:

1. Reads Ollama's ROCm libraries into the page cache, so GPU discovery
   finishes inside Ollama's fixed 30-second window. Without this, Ollama fell
   back to the CPU and logged only an `INFO` line.
2. Starts `ollama serve` under `srun` on one GCD, bound to `127.0.0.1` on a
   per-job port, probing only the ROCm backend. If Ollama does not report a
   ROCm GPU, the job **exits with an error** rather than serving from the CPU.
3. On first use, imports the GGUF as `qwen3-32b-q4km-base`. This copies the
   19.8 GB file into `$OLLAMA_MODELS` (default `$LLM_ROOT/ollama-models`) and
   took 72–185 s. Later jobs reuse it.
4. Creates the served model `qwen3-32b-q4km` from the base model, adding
   `num_ctx 4096` and `num_thread` = cores in the allocation. This is instant
   and copies nothing. Without `num_thread`, Ollama's runner starts 64 threads
   on an 8-core allocation and generates ~40% slower.
5. Prints `ollama show` (architecture, quantisation, capabilities `tools`,
   `thinking`, `completion`; template source `gguf_chat_template`) and the
   imported blob's SHA256, which must equal the GGUF's.

Settings exported to the server: `OLLAMA_NUM_PARALLEL=1`,
`OLLAMA_MAX_LOADED_MODELS=1`, `OLLAMA_CONTEXT_LENGTH=4096`,
`OLLAMA_FLASH_ATTENTION=1`, `OLLAMA_KV_CACHE_TYPE=f16`, `OLLAMA_KEEP_ALIVE=-1`
(keep the model loaded for the whole job), `OLLAMA_NOHISTORY=1`.

**Ollama has no authentication.** Other users on a shared GPU node can reach
its port while your job runs. See the [security section](../README.md#security-shared-gpu-nodes).

## Use

Through the tunnel printed in the job log (`OLLAMA_HOST=127.0.0.1:<port>`):

```bash
curl http://127.0.0.1:<port>/api/chat -d '{
  "model": "qwen3-32b-q4km", "stream": false, "think": false,
  "messages": [{"role": "user", "content": "What is a prophage?"}]}'
```

`"think": true` returns Qwen3's reasoning separately in `message.thinking`.
Ollama also serves an OpenAI-compatible API under `/v1`.
On the compute node itself (e.g. `ssh nidXXXXXX`), you can also use the CLI:
`OLLAMA_HOST=127.0.0.1:<port> $LLM_ROOT/ollama-v0.40.18/bin/ollama run qwen3-32b-q4km`.

## Troubleshooting

- `inference compute ... library=cpu` in `runs/ollama-<job>/server.log`, or
  `GPU discovery watchdog timed out`: the libraries were not in the page cache
  in time. The launcher's warm-up should prevent this. If `/scratch` is very
  slow, rerun the job.
- Generation around 23 tok/s instead of ~40: the runner is not getting
  `num_thread`. Check `num_thread` in `ollama show qwen3-32b-q4km`, and check
  that API requests do not override it.
