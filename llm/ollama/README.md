# Ollama on Setonix

Status: unvalidated installation recipe. Read [shared setup](../README.md) first.

## Install without root or a system service

Select a pinned Ollama release and download its Linux amd64 archive and matching ROCm companion archive from the [official releases](https://github.com/ollama/ollama/releases). Check that release's driver requirements against Setonix. Recent upstream documentation uses .tar.zst archives; older releases may differ.

For downloaded .tar.zst archives, set OLLAMA_ARCHIVE, OLLAMA_ROCM_ARCHIVE and a new OLLAMA_PREFIX outside this checkout. Verify any published checksums before extraction. A tar with zstd support is required.

```bash
: "${OLLAMA_PREFIX:?Set a new installation directory}"
: "${OLLAMA_ARCHIVE:?Set the downloaded main archive path}"
: "${OLLAMA_ROCM_ARCHIVE:?Set the matching ROCm archive path}"
mkdir "$OLLAMA_PREFIX"
tar --zstd -xf "$OLLAMA_ARCHIVE" -C "$OLLAMA_PREFIX"
tar --zstd -xf "$OLLAMA_ROCM_ARCHIVE" -C "$OLLAMA_PREFIX"
export OLLAMA_BIN="$OLLAMA_PREFIX/bin/ollama"
"$OLLAMA_BIN" --version
```

Preserve the archive's bin/lib layout. Do not use the system-wide installer, sudo or systemd on Setonix. Validate binary and library compatibility on a compute node; if unsuitable, investigate a site-supported Apptainer/Singularity ROCm container.

## Start the server

Set a writable OLLAMA_MODELS directory outside Git with room for an imported copy of the model, then submit from the pawsey checkout:

```bash
export OLLAMA_MODELS=/absolute/path/to/ollama-models
sbatch --account="${PAWSEY_PROJECT}-gpu" llm/ollama/serve.slurm
```

Establish a tunnel to port 11434 as described in the shared README. Ollama is an API/CLI server; this recipe does not install a browser chat interface.

## Import the same GGUF

Create a local Modelfile (outside this repository) containing the absolute path as seen by the server on Setonix:

```text
FROM /absolute/path/to/model.gguf
PARAMETER num_ctx 4096
```

Run the following from a client shell with access to both the model file and running server (for example on the allocated compute node via a site-approved connection):

```bash
export OLLAMA_HOST=127.0.0.1:11434
"$OLLAMA_BIN" create shared-gguf -f /absolute/path/to/Modelfile
"$OLLAMA_BIN" run shared-gguf
"$OLLAMA_BIN" ps
```

The import may copy weights into OLLAMA_MODELS. Do not assume disk deduplication. Validate the inferred chat template with ollama show --modelfile shared-gguf and compare it with the llama.cpp configuration. Match sampling and reasoning settings explicitly when benchmarking.
