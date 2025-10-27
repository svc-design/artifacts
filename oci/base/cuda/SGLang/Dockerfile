# CUDA 12.1 runtime base for SGLang
FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-venv python3-pip git curl ca-certificates build-essential \
    && rm -rf /var/lib/apt/lists/*

ENV PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN pip3 install --upgrade pip \
    && pip3 install --extra-index-url https://download.pytorch.org/whl/cu121 \
         torch==2.3.1 torchvision==0.18.1 torchaudio==2.3.1 \
    && pip3 install sglang==0.2.3 uvicorn fastapi

EXPOSE 30000

ENV SGLANG_MODEL="Qwen/Qwen2-7B-Instruct" \
    SGLANG_PORT=30000 \
    SGLANG_ARGS="--tp 1 --context-length 8192"

RUN useradd -m -u 10001 app && mkdir -p /models && chown -R app:app /models
USER app

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s CMD curl -fsS http://127.0.0.1:${SGLANG_PORT}/v1/models || exit 1

ENTRYPOINT ["bash","-lc","python3 -m sglang.launch_server --model \"$SGLANG_MODEL\" --port $SGLANG_PORT --trust-remote-code --enable-openai-compatible-api $SGLANG_ARGS"]
