#!/bin/bash
# Build the pinned llama.cpp release with HIP for MI250X (gfx90a) against the
# site ROCm module, and install it into LLAMA_PREFIX. Compiling does not need a
# GPU, but the rocm/7.x modules only load on GPU nodes (on CPU `work` nodes Lmod
# reports "require a toolchain that is incompatible"), so this takes one GCD
# allocation pack (8 cores). Usage:
#   sbatch --account="${PAWSEY_PROJECT}-gpu" --export=ALL llm/llama.cpp/build.slurm
#SBATCH --job-name=llm-llamacpp-build
#SBATCH --partition=gpu
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:1
#SBATCH --time=02:00:00
#SBATCH --output=%x-%j.out
set -euo pipefail
HERE=${LLM_DIR:-${SLURM_SUBMIT_DIR:-.}/llm}
# shellcheck source=../versions.env
source "$HERE/versions.env"

if [[ -x $LLAMA_PREFIX/bin/llama-server ]]; then
    echo "Already installed: $LLAMA_PREFIX"; exit 0
fi
module load "$LLAMA_ROCM_MODULE" "$LLAMA_CMAKE_MODULE"
module -t list 2>&1

src=$LLM_ROOT/src/llama.cpp-$LLAMA_REF
if [[ ! -d $src/.git ]]; then
    git clone --depth 1 --branch "$LLAMA_REF" https://github.com/ggml-org/llama.cpp.git "$src"
fi
commit=$(git -C "$src" rev-parse HEAD)
echo "llama.cpp $LLAMA_REF = $commit"

build=$src/build-hip
rm -rf "$build"
# Static libraries: the installed binaries then depend only on the ROCm
# module's shared libraries, which serve.slurm loads again at run time.
HIPCXX="$(hipconfig -l)/clang" HIP_PATH="$(hipconfig -R)" \
cmake -S "$src" -B "$build" \
    -DGGML_HIP=ON -DGPU_TARGETS="$LLAMA_GPU_TARGETS" \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
    -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF \
    -DCMAKE_INSTALL_PREFIX="$LLAMA_PREFIX.incomplete"
SECONDS=0
cmake --build "$build" --parallel "$(nproc)"
echo "Build took ${SECONDS}s"
rm -rf "$LLAMA_PREFIX.incomplete"
cmake --install "$build"
printf 'ref=%s\ncommit=%s\nrocm=%s\ntargets=%s\nbuilt=%s\n' \
    "$LLAMA_REF" "$commit" "$LLAMA_ROCM_MODULE" "$LLAMA_GPU_TARGETS" "$(date -Is)" \
    > "$LLAMA_PREFIX.incomplete/BUILD_INFO"
mv "$LLAMA_PREFIX.incomplete" "$LLAMA_PREFIX"
rm -rf "$build"   # ~thousands of object files; the source tree is kept for reference
"$LLAMA_PREFIX/bin/llama-server" --version
ldd "$LLAMA_PREFIX/bin/llama-server" | grep -E "hip|roc|not found" || true
echo "Installed llama.cpp into $LLAMA_PREFIX"
