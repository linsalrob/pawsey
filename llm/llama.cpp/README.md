# llama.cpp on Setonix

Status: unvalidated installation recipe. Read [shared setup](../README.md) first.

## Build in user space

Load a compatible site ROCm and CMake module. Choose a release tag or commit explicitly (LLAMA_REF), a new source directory (LLAMA_SRC), and build inside an appropriate allocation. Confirm hipconfig and cmake are available.

```bash
: "${LLAMA_REF:?Set a release tag or commit}"
: "${LLAMA_SRC:?Set a new source directory outside this repository}"
git clone https://github.com/ggml-org/llama.cpp.git "$LLAMA_SRC"
git -C "$LLAMA_SRC" checkout --detach "$LLAMA_REF"
HIPCXX="$(hipconfig -l)/clang" HIP_PATH="$(hipconfig -R)" \
  cmake -S "$LLAMA_SRC" -B "$LLAMA_SRC/build" \
  -DGGML_HIP=ON -DGPU_TARGETS=gfx90a -DCMAKE_BUILD_TYPE=Release
cmake --build "$LLAMA_SRC/build" --parallel 8
git -C "$LLAMA_SRC" rev-parse HEAD
"$LLAMA_SRC/build/bin/llama-server" --version
```

gfx90a is the MI250X target. Compiler/module compatibility still needs validation on the installed Setonix stack. Keep the same runtime library environment when serving. Check the chosen revision's build documentation if flags change.

## Serve

From the pawsey checkout, after loading the required modules:

```bash
export LLAMA_SERVER="$LLAMA_SRC/build/bin/llama-server"
export MODEL_GGUF=/absolute/path/to/model.gguf
sbatch --account="${PAWSEY_PROJECT}-gpu" llm/llama.cpp/serve.slurm
```

The launcher enables GPU offload, a 4096-token context and one slot. For sharded models point MODEL_GGUF at the first shard and keep all shards together.

After establishing the tunnel described in the shared README, open http://localhost:8080 for the built-in chat UI, or inspect http://localhost:8080/v1/models. Check logs for actual GPU offload. Tool calling and template validation are subsequent milestones, not implied by basic chat success.
