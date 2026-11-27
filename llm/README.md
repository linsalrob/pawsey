# Local LLMs on Setonix

Status: initial recipes; not yet validated on Setonix. No GPU benchmark has been run.

Two independent runtimes can use the same GGUF weights:
- [Ollama](ollama/README.md)
- [llama.cpp](llama.cpp/README.md)

Start with a Qwen3-32B Q4_K_M GGUF and a 4096-token context, one request at a time. This is a candidate baseline, not a validated recommendation or a requirement. Use a smaller model for initial diagnostics if necessary.

## Prerequisites and storage

You need a Pawsey GPU allocation, a writable installation directory and model storage outside Git. Set PAWSEY_PROJECT to your project. Check current modules with module avail rocm and module avail cmake, and inspect the GPU partition limits before submitting. Use the site's installed drivers; do not install drivers or system services.

Place source/install files in an approved project software location and model/cache files in project storage with sufficient quota. Scratch may be purged. Download weights and software through the site's approved transfer workflow before starting inference jobs. Keep model weights, caches and logs out of this repository.

Choose an upstream model revision and record its URL, license, GGUF filename, quantisation and SHA256. For split GGUFs record every shard. A publisher checksum should be verified when available; a locally computed checksum alone only records identity.

## Slurm

The included launchers request one GPU/GCD and one task. Pass the account on the command line because shell variables are not expanded in SBATCH directives:

```bash
sbatch --account="${PAWSEY_PROJECT}-gpu" llm/llama.cpp/serve.slurm
# OR
sbatch --account="${PAWSEY_PROJECT}-gpu" llm/ollama/serve.slurm
```

The examples use gpu-dev and 30 minutes; check current partition availability and limits. Run only one runtime at a time initially. Preserve scheduler-provided GPU visibility. GPU HBM and Slurm host-memory limits are separate: a model may fit on the accelerator but exceed host RAM while loading.

Both launchers bind to compute-node loopback. Use a site-permitted SSH tunnel to the allocated node, e.g. from your laptop:

```bash
ssh -N -J USER@setonix.pawsey.org.au -L 8080:127.0.0.1:8080 USER@COMPUTE_NODE
```

Substitute the node printed in the job log; for Ollama use port 11434 at both ends. Direct SSH to the compute node must be permitted by site policy and your allocation. If unavailable, follow Pawsey's supported tunnelling procedure; do not expose the unauthenticated service on all network interfaces. Stop the job when finished.

## Validation before calling a recipe tested

Record date, runtime version/commit, ROCm module and driver, GPU model/count, model checksum, Slurm allocation and peak host/GPU memory. Verify GPU offload in runtime logs (and ollama ps for Ollama); a successful answer alone can be CPU fallback.

Check CLI/API generation, context settings, chat template, reasoning mode, stop tokens, clean shutdown and an actual SSH connection. Compare identical prompts and generation limits at matched settings. Report cold loading separately from warm prompt-processing and generation speed. Do not expect bit-identical results between runtimes.

Keep a tested-version table here after on-cluster validation. Current tested combinations: none.

## Sources

- [Pawsey GPU quick start](https://pawsey.atlassian.net/wiki/spaces/US/pages/51928618)
- [Ollama Linux installation](https://docs.ollama.com/linux)
- [Ollama GGUF import](https://docs.ollama.com/import)
- [llama.cpp HIP build](https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md#hip)
