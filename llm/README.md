# Local LLMs on Setonix

Run open-weight large language models on Setonix's AMD MI250X GPUs with either
[Ollama](ollama/README.md) or [llama.cpp](llama.cpp/README.md), both serving the
**same GGUF file**. Everything installs in user space: no root, no system
service, no container.

Status: **validated on Setonix, 2026-11-27**, one GCD, one request at a time.
See [tested versions](#tested-versions) and [results](#validation-results).

## Quick start

From the root of this repository, with `PAWSEY_PROJECT` set:

```bash
export LLM_ROOT=/scratch/$PAWSEY_PROJECT/$USER/llm   # the default; anywhere with ~45 GB free
mkdir -p "$LLM_ROOT"

# 1. Download and verify the model (copy partition, ~20 GB, a few minutes)
sbatch --account="$PAWSEY_PROJECT" --export=ALL llm/fetch_model.slurm

# 2. Install one or both runtimes
sbatch --account="$PAWSEY_PROJECT" --export=ALL llm/ollama/install.slurm          # copy partition, ~2 min
sbatch --account="${PAWSEY_PROJECT}-gpu" --export=ALL llm/llama.cpp/build.slurm  # 1 GCD, ~6 min

# 3. Validate: start the server, run the benchmark, shut down (~3 min each)
LLM_BENCH=1 sbatch --account="${PAWSEY_PROJECT}-gpu" --export=ALL llm/ollama/serve.slurm
LLM_BENCH=1 sbatch --account="${PAWSEY_PROJECT}-gpu" --export=ALL llm/llama.cpp/serve.slurm

# 4. Serve for interactive use (prints an SSH tunnel command in the job log)
sbatch --account="${PAWSEY_PROJECT}-gpu" --export=ALL --time=02:00:00 llm/llama.cpp/serve.slurm
```

`--export=ALL` matters: Setonix sets `SBATCH_EXPORT=NONE`, so without it the job
does not see `LLM_ROOT` or other overrides. Job logs are written to the
submission directory unless you pass `-o`. The serve launchers default to the
`gpu-dev` partition (4 h limit, few running jobs per user); add `-p gpu` for
longer sessions or when you already have a `gpu-dev` job.

All pins (model revision and SHA256, runtime versions, checksums, ROCm module)
live in [`versions.env`](versions.env). Every script sources it, so changing a
pin there changes it everywhere. Re-run the validation job after any change.

## Layout under `LLM_ROOT`

| Path | What | Size / files |
|---|---|---|
| `models/Qwen3-32B-Q4_K_M.gguf` | the shared GGUF | 19.8 GB |
| `llama.cpp-b12807/` | llama.cpp install | 1.9 GB |
| `src/llama.cpp-b12807/` | llama.cpp source (build tree removed) | 240 MB, ~4,800 files |
| `ollama-v0.40.18/` | Ollama install (CUDA libraries skipped) | 2.2 GB, ~1,850 files |
| `ollama-models/` | Ollama's imported copy of the GGUF | 19.8 GB |
| `downloads/` | Ollama release archives; delete after installing | 2.6 GB |
| `runs/<runtime>-<jobid>/` | server log, memory trace, benchmark results | small |
| `llama-server.key` | API key for llama-server (mode 600) | — |

`/scratch` is purged 21 days after files were last accessed. Keep a copy of the
GGUF elsewhere (e.g. Acacia) if you need it longer; the fetch job re-downloads
and re-verifies it if it disappears.

## Model

The baseline is **Qwen3-32B, Q4_K_M** from the publisher's own GGUF repository
(`Qwen/Qwen3-32B-GGUF`, revision `938a743`, Apache-2.0). The download is
verified against the publisher's SHA256 (the Hugging Face LFS object ID). It is
a reasonable starting point that fits comfortably on one 64 GB GCD; it is not a
claim that it is the best model for any particular task.

Ollama stores the imported model as a blob named by its SHA256. The validation
job prints that name, so you can confirm both runtimes load byte-identical
weights.

## Matched settings

Both launchers use the same settings, so differences in output and speed come
from the runtimes, not the configuration:

- one GCD, one request slot, 4096-token context;
- every layer on the GPU, flash attention on, f16 KV cache, batch and micro-batch 512;
- CPU threads = physical cores in the allocation (8 per GCD; see below);
- the chat template embedded in the GGUF (Ollama reports `template source gguf_chat_template`);
- the benchmark uses greedy decoding (temperature 0, top-k 1, seed 42), with reasoning
  ("thinking") off except for one prompt that checks it.

## Security: shared GPU nodes

A one-GCD job shares its node with other users' jobs, and **anyone logged in to
that node can connect to a port on its loopback interface**. So:

- **llama.cpp** requires an API key. The launcher creates `$LLM_ROOT/llama-server.key`
  (mode 600); send it as `Authorization: Bearer <key>`. Requests without it get 401.
- **Ollama has no authentication.** Any user on the node could use your server
  while it runs. Do not send confidential or unpublished material to it unless
  you hold the whole node (`sbatch --exclusive`, which is billed for all 8 GCDs).
- Both servers bind to `127.0.0.1` only and use a port derived from the job ID
  (20000–39999), so two users' jobs on one node do not collide.

## Connecting from your computer

The job log prints the exact command, for example:

```bash
ssh -N -L 33342:127.0.0.1:33342 -J USER@setonix.pawsey.org.au USER@nid002160
```

Then open `http://127.0.0.1:33342` locally. For llama.cpp this serves a chat
page plus an OpenAI-compatible API under `/v1`. Ollama serves its own API under
`/api` and an OpenAI-compatible one under `/v1`. Both `/v1/chat/completions`
endpoints were tested through a forwarded port.

Tested: `ssh -L` forwarding to a running job's node, both directly from a login
node and with the `-J USER@setonix.pawsey.org.au` jump shown above. Not tested:
the laptop end of that command. Pawsey's `pam_slurm_adopt` allows SSH to a
compute node **only while you have a job running on it**, so the tunnel closes
when the job ends.

The llama.cpp chat page is served gzip-compressed. Browsers handle that, but
plain `curl` without `Accept-Encoding: gzip` gets HTTP 415, which does not mean
the server is broken. Cancel the job (`scancel <jobid>`) when you are finished:
the GPU is billed until the job ends. `scancel` triggers the launcher's clean
shutdown (tested: nothing is left on the GPU).

## Tested versions

| Component | Version | Notes |
|---|---|---|
| GPU | AMD Instinct MI250X (gfx90a), one GCD | `amdgpu` driver 6.14.14 |
| llama.cpp | `b12807` (`e0b9fd7`) | built with `rocm/7.0.1`, `cmake/3.31.9`, `gcc-native/14.2`, static libraries |
| Ollama | `v0.40.18` | upstream `linux-amd64` + `linux-amd64-rocm` archives; bundles ROCm 7.2.1 libraries and a llama.cpp `llama-server` (`f5e6915c2`) |
| Model | `Qwen/Qwen3-32B-GGUF@938a743`, `Qwen3-32B-Q4_K_M.gguf` | SHA256 `efd97156…d57d1f689` |

## Validation results

Sequential jobs on the `gpu` partition, 2026-11-27, one GCD each
(Slurm `AllocTRES` `cpu=16,mem=29440M,gres/gpu=1,billing=128`). Speeds are the
runtimes' own timers. Wall-clock times agree to within a few percent once the
model is loaded.

| Measure | llama.cpp b12807 | Ollama v0.40.18 |
|---|---:|---:|
| `llama-bench` pp512 / tg128 (tok/s) | 832 / 37.7 | — |
| Generation, median over replies ≥ 60 tokens (tok/s) | 37.7 | 40.1 |
| Prompt processing, 3,442-token prompt (tok/s) | 749 | 729 |
| Cold load to first answer | 12 s (start to ready) | 15.5 s (first-request load) |
| One-time GGUF import | — | 72–185 s |
| Peak VRAM | 20.6 GB | 20.7 GB |
| Slurm MaxRSS of the server step | 1.7 GB | 1.9 GB |
| Whole validation job | 2 min 19 s | 1 min 51 s |
| VRAM after shutdown / leftover processes | 12 MiB / none | 12 MiB / none |

A second, independent run of the whole guide from an empty `LLM_ROOT` (fetch,
install, build, both validations; jobs chained with dependencies) passed every
check, with 37.5 and 39.4 tok/s generation. Prompt-processing speed on the long
prompt varied more between runs and nodes (540–750 tok/s), as did the import
time, which depends on `/scratch` throughput.

Behaviour checks, all passed on both runtimes:

- every layer (65/65) offloaded to the GPU, confirmed in the runtime log and `ollama ps` (`100% GPU`);
- replies end with `stop`, and no `<|im_end|>`, `<think>` or similar tokens leak into replies;
- with thinking on, the reasoning comes back separately from the answer
  (`reasoning_content` from llama.cpp, `thinking` from Ollama), and both reach the right answer;
- under greedy decoding, 6 of 11 replies are character-for-character identical between
  the runtimes, and the rest diverge only after 58–828 characters: same weights and
  template, with ordinary floating-point drift between builds.

### Answer quality

Each reply was graded against the reference notes in
[`bench/prompts.jsonl`](bench/prompts.jsonl) by a reviewer other than the model
under test. The questions are simple, so this is a smoke test, not an
evaluation of fitness for research use.

| Prompt | Grade (both runtimes unless noted) |
|---|---|
| gen-3, code-1, code-2, micro-2, micro-3, think-1 | correct and adequate |
| gen-1 (blue sky) | correct but vague: no Rayleigh scattering, no wavelength dependence |
| gen-2 (boiling point) | correct value; mechanism loosely stated (no vapour pressure) |
| micro-1 (Cas9) | correct; omits the PAM and the double-strand break |
| micro-4 (Gram stain) | correct. The Ollama reply added an **unsupported figure**: peptidoglycan "about 1–2% of the cell wall by weight" (textbooks give roughly 10% for Gram-negative bacteria) |
| long-1 (largest of 150 values) | **wrong** with thinking off; right with thinking on (~2,900 reasoning tokens, ~80 s) |

No reply expressed any uncertainty, including the wrong ones. Check facts,
figures and anything numeric against a source.

### Long context (32k)

With `LLM_CTX=32768` (Qwen3's native maximum), one GCD holds the model plus an
8 GB KV cache, peaking at 27.8 GB VRAM. On ~31k-token prompts prefill slows to
~500 tok/s, so a full-context prompt takes about a minute before the first
token, and generation drops to ~34 tok/s. Both runtimes behaved the same.

The generated known-answer prompts (`--lookup-rows`, `--long-rows`) give a
warning for retrieval-style use. Asked to copy one value from a table, the model
was right at ~3.4k and ~31k tokens but at ~15k tokens returned the value from
the **next row**, identically in both runtimes. It also never compared 150
values correctly without thinking. Use tools for exact lookups and arithmetic
over tables, and use the model to explain their results.

```bash
LLM_CTX=32768 LLM_BENCH=1 LLM_BENCH_ARGS="--long-only --long-rows 150 --lookup-rows 150 650 1300 --think-long" \
  sbatch --account="${PAWSEY_PROJECT}-gpu" --export=ALL -p gpu llm/llama.cpp/serve.slurm
```

Ollama reuses the cached prompt prefix between requests and has no setting to
turn that off. A prompt that shares a prefix with the previous one, such as the
same table with a different question, therefore shows an unrealistically high
prompt speed. `bench.py` turns caching off for llama.cpp.

**Host memory.** `ps` reports ~15–19 GB resident for the server because the
memory-mapped GGUF counts as resident. Those pages are shared file cache, not
private memory. Slurm's MaxRSS for the server step was under 2 GB, and the
default 29 GB that comes with one GCD was ample. `ollama create` reads the whole
file (12 GB MaxRSS in that step) but also fits.

## Lessons from validation

1. **`rocm/7.x` modules only load on GPU nodes.** On CPU (`work`) nodes Lmod
   says the module "require[s] a toolchain that is incompatible". So
   `build.slurm` compiles on one GCD (8 cores, ~6 min).
2. **Ollama falls back to the CPU without an error if GPU discovery takes more than 30 s.**
   The timeout is hard-coded in Ollama (`discover/runner.go`). Loading its
   2.4 GB of ROCm libraries cold from `/scratch` took longer than that. The
   launcher now reads those libraries into the page cache first (3–7 s), lets
   Ollama probe only its ROCm backend, and stops the job if Ollama reports no
   ROCm GPU. Reported upstream as
   [ollama#19971](https://github.com/ollama/ollama/issues/19971).
3. **Set the CPU thread count to the allocation.** Both runtimes default to the
   node's 64 physical cores, not the 8 a GCD allocation gets. Inside an `srun`
   step this oversubscription cut Ollama's generation speed from 40 to 23 tok/s.
   llama.cpp b12807 was unaffected, but the launchers set it for both.
   `SLURM_CPUS_ON_NODE` is not a reliable source for this count: it reads 8 in
   the batch step and 16 in the `srun` step. The launchers use `nproc` divided
   by threads per core instead. Ollama has no server-wide thread setting, so
   the launcher bakes `num_thread` into the served model; API clients can still
   override it per request. Upstream:
   [ollama#17916](https://github.com/ollama/ollama/issues/17916).
4. **Both runtimes are llama.cpp underneath.** Ollama v0.40.18 runs its own
   bundled `llama-server`, so speeds are close. Its ~6% faster generation (40
   vs 37.7 tok/s) is **not** explained by any of these, each tested with
   `llama-bench` on the same node:
   - its ROCm 7.2.1 runtime libraries: our binary gives the same speed when run against them;
   - its llama.cpp commit (`f5e6915c2`): built with our recipe, it gives 37.6 tok/s;
   - building without OpenMP (`-DGGML_OPENMP=OFF`), as Ollama does;
   - compiling for `gfx90a:xnack-` rather than generic `gfx90a`.

   The remaining difference is Ollama's ROCm 7.2.1 compiler, which needs a
   ROCm 7.2 build container to test. That has not been done.

## Benchmark and validation tools

- [`bench/bench.py`](bench/bench.py) sends the prompts in `bench/prompts.jsonl`, plus
  generated long-context questions with known answers (`--long-rows`,
  `--lookup-rows`, `--think-long`), to either server at matched settings. It
  writes one JSON record per prompt and marks long-context answers right or
  wrong. Standard library only. Pass extra options through `LLM_BENCH_ARGS`.
- [`bench/summarise.py`](bench/summarise.py) compares two runs (speeds, long-context
  answer, reasoning separation, stop-token leaks, identical replies).
- [`lib.sh`](lib.sh) holds the helpers the launchers share: port choice,
  readiness wait, provenance, VRAM/RSS sampling, clean-shutdown check and thread count.

Speed is not quality. Chat working does not mean tool calling works. Score
answers against references, not with the model grading itself.

## Sources

- [Pawsey: Setonix GPU partition quick start](https://pawsey.atlassian.net/wiki/spaces/US/pages/51928618)
- [Ollama Linux installation](https://docs.ollama.com/linux) and [GPU support](https://github.com/ollama/ollama/blob/v0.40.18/docs/gpu.md)
- [Ollama GGUF import](https://docs.ollama.com/import)
- [llama.cpp HIP build](https://github.com/ggml-org/llama.cpp/blob/b12807/docs/build.md#hip)
- [Qwen3-32B-GGUF model card](https://huggingface.co/Qwen/Qwen3-32B-GGUF)
