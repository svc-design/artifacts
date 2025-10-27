# Ollama runtime image that leans on host NVIDIA drivers via container toolkit
FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates unzip gnupg \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://ollama.com/download/ollama-linux-amd64.tgz | tar -xz -C /usr/local/bin \
    && chmod +x /usr/local/bin/ollama

RUN useradd -m -u 10001 app && mkdir -p /home/app/.ollama && chown -R app:app /home/app
USER app

ENV OLLAMA_HOST=0.0.0.0:11434 \
    OLLAMA_MODELS=/home/app/.ollama/models \
    OLLAMA_MODEL="phi3:latest"

EXPOSE 11434

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s CMD curl -fsS http://127.0.0.1:11434/api/tags || exit 1

ENTRYPOINT ["bash","-lc","set -euo pipefail; \
  ollama serve & \
  for i in $(seq 1 30); do sleep 1; curl -fsS http://127.0.0.1:11434/api/tags && break || true; done; \
  ollama pull \"$OLLAMA_MODEL\" || true; \
  wait -n"]
