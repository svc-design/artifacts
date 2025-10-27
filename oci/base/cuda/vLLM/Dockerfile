# CUDA 12.1 + cuDNN8 runtime base — tested with recent PyTorch wheels
FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive

# System deps + Python
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-venv python3-pip git curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install CUDA-enabled PyTorch + vLLM
RUN pip3 install --upgrade pip \
    && pip3 install --extra-index-url https://download.pytorch.org/whl/cu121 \
         torch==2.3.1 torchvision==0.18.1 torchaudio==2.3.1 \
    && pip3 install vllm==0.5.2 uvicorn fastapi

EXPOSE 8000

ENV MODEL_PATH="meta-llama/Meta-Llama-3-8B-Instruct" \
    VLLM_ARGS="--max-model-len 8192 --gpu-memory-utilization 0.9" \
    HF_HOME=/models/.cache \
    VLLM_WORKER_USE_GRAPH_EXECUTOR=1

RUN useradd -m -u 10001 app && mkdir -p /models && chown -R app:app /models
USER app

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s CMD curl -fsS http://127.0.0.1:8000/v1/models || exit 1

ENTRYPOINT ["bash","-lc","vllm serve \"$MODEL_PATH\" --port 8000 --api-key dummy $VLLM_ARGS"]
