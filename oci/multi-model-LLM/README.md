# CUDA LLM Serving — vLLM / SGLang / Ollama (Kubernetes)

This package bundles three CUDA-ready images plus a single Helm chart that can serve **multiple models** behind one host with **path-based routing** such as:

- `https://api.svc.plus/v1/llama3` → vLLM (OpenAI-compatible)
- `https://api.svc.plus/v1/qwen2`  → SGLang (OpenAI-compatible)
- `https://api.svc.plus/v1/phi3`   → Ollama `/api/*`

The Dockerfiles live under [`oci/base/cuda`](../base/cuda/), while the Helm chart is in [`charts/model-serving`](charts/model-serving/).

## Prerequisites

- Kubernetes ≥ 1.25
- NVIDIA GPUs on worker nodes + NVIDIA Container Toolkit
- Ingress Controller (e.g. NGINX) and TLS secret if using HTTPS
- (Optional) GitHub Container Registry (GHCR) for distributing images and charts

## Build & Publish

```bash
# 1) Build and push images to GHCR (adjust ORG)
make -C oci/base/cuda ORG=svc-design docker-build docker-push

# 2) Lint & package the chart
make -C oci/multi-model-LLM helm-lint helm-package VERSION=0.1.0

# 3) Push chart as OCI to GHCR
make -C oci/multi-model-LLM ORG=svc-design VERSION=0.1.0 helm-push
```

> Authenticate GHCR first:
>
> ```bash
> echo $GHCR_TOKEN | docker login ghcr.io -u <GITHUB_USER> --password-stdin
> helm registry login ghcr.io -u <GITHUB_USER> -p $GHCR_TOKEN
> ```

## Install

```bash
# install into namespace llm with release name ms
make -C oci/multi-model-LLM install RELEASE=ms NAMESPACE=llm
```

## Configure Models

Edit [`charts/model-serving/values.yaml`](charts/model-serving/values.yaml) and extend the `models:` list. Example:

```yaml
models:
  - name: llama3-8b-vllm
    engine: vllm
    image: "model-serving/vllm"
    tag: "cuda12"
    path: v1/llama3
    env:
      - name: MODEL_PATH
        value: meta-llama/Meta-Llama-3-8B-Instruct
      - name: VLLM_ARGS
        value: --max-model-len 8192 --gpu-memory-utilization 0.9
    resources:
      limits:
        nvidia.com/gpu: 1

  - name: qwen2-7b-sglang
    engine: sglang
    image: "model-serving/sglang"
    tag: "cuda12"
    path: v1/qwen2
    env:
      - name: SGLANG_MODEL
        value: Qwen/Qwen2-7B-Instruct

  - name: phi3-ollama
    engine: ollama
    image: "model-serving/ollama"
    tag: latest
    path: v1/phi3
    env:
      - name: OLLAMA_MODEL
        value: phi3:latest
```

Deployments and services are generated per model, and a single ingress exposes them under unique paths.

## Runtime Notes

* **GPU scheduling**: Templates set `runtimeClassName: nvidia` and default GPU limits. Ensure the cluster has the NVIDIA device plugin and RuntimeClass defined, or override `runtimeClassName` per model.
* **Storage**: vLLM/SGLang cache defaults to the container filesystem. Mount an external volume by extending the template if persistence is required.
* **Authentication**: vLLM launches with a dummy API key. Place an API gateway or ingress authentication in front for production.
* **Scaling**: Increase `replicas` per model and add engine-specific flags through environment variables for tensor parallelism or sharding.

## Uninstall

```bash
make -C oci/multi-model-LLM uninstall RELEASE=ms NAMESPACE=llm
```

## License

MIT
