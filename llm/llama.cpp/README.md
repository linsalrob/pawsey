# llama.cpp on Setonix

Read the [shared guide](../README.md) first: it covers the model, storage,
matched settings, security and results. This page covers what is specific to llama.cpp.

Validated: llama.cpp **b12807** (`e0b9fd7`) built with `rocm/7.0.1` on one MI250X
GCD, 2026-11-27.

## Build

```bash
sbatch --account="${PAWSEY_PROJECT}-gpu" --export=ALL llm/llama.cpp/build.slurm
```

[`build.slurm`](build.slurm) shallow-clones the pinned tag into
`$LLM_ROOT/src/llama.cpp-b12807`. It configures with HIP for `gfx90a` using the
site `rocm/7.0.1` and `cmake/3.31.9` modules (with the default `gcc-native/14.2`),
builds with static libraries and no tests or examples, and installs into
`$LLM_ROOT/llama.cpp-b12807`. It records the ref, commit, ROCm module and build
date in `BUILD_INFO`, then removes the build tree (2.2 GB). Compiling took
5.3 minutes on one GCD's 8 cores.

It runs on a GPU node, not the cheaper `work` partition, because the `rocm/7.x`
modules cannot be loaded on CPU nodes. The installed binaries link to
`/opt/rocm-7.0.1`, so [`serve.slurm`](serve.slurm) loads the same module at run time.

Overrides (environment variables, with `--export=ALL`):
- `LLAMA_REF`: a release tag or a full commit SHA. Prefer tags: for an untagged
  commit the build cannot find a matching prebuilt web UI and falls back to the
  latest one, so the build is not fully pinned.
- `LLAMA_GPU_TARGETS`: default `gfx90a`. `gfx90a:xnack-` was tested and made no
  measurable difference.
- `LLAMA_CMAKE_ARGS`: extra CMake options, recorded in `BUILD_INFO`.
- `LLAMA_PREFIX`: the install location, so variants can sit side by side.

The build fetches llama.cpp's prebuilt web UI for this tag during configuration
(`LLAMA_USE_PREBUILT_UI`, on by default). Pass `-DLLAMA_USE_PREBUILT_UI=OFF` if
the build node has no internet access.

## Serve

```bash
# validation: llama-bench, then the matched prompt benchmark, then stop
LLM_BENCH=1 sbatch --account="${PAWSEY_PROJECT}-gpu" --export=ALL llm/llama.cpp/serve.slurm
# interactive use
sbatch --account="${PAWSEY_PROJECT}-gpu" --export=ALL --time=02:00:00 llm/llama.cpp/serve.slurm
```

`llama-server` runs under `srun` on one GCD with:
`--n-gpu-layers 999 --ctx-size 4096 --parallel 1 --flash-attn on --batch-size 512
--ubatch-size 512 --threads <cores> --jinja --host 127.0.0.1 --port <per-job>
--api-key-file $LLM_ROOT/llama-server.key`.

The launcher creates the API key file on first use (mode 600) and enforces it:
requests without `Authorization: Bearer <key>` get HTTP 401. `/health` stays open.
Loading took 12 s from process start to ready.

## Use

Through the tunnel printed in the job log:

```bash
KEY=$(cat $LLM_ROOT/llama-server.key)   # copy the key to your computer securely if needed
curl http://127.0.0.1:<port>/v1/chat/completions -H "Authorization: Bearer $KEY" \
  -H 'Content-Type: application/json' -d '{
  "messages": [{"role": "user", "content": "What is a prophage?"}],
  "chat_template_kwargs": {"enable_thinking": false}}'
```

With thinking on (the default for Qwen3), the reasoning comes back separately in
`message.reasoning_content`. `http://127.0.0.1:<port>/` serves the built-in chat
page, which asks for the API key.
