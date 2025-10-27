ORG ?= your-org
REGISTRY ?= ghcr.io/$(ORG)/model-serving
VLLM_TAG ?= cuda12
SGLANG_TAG ?= cuda12
OLLAMA_TAG ?= latest

.PHONY: docker-build docker-push docker-build-vllm docker-build-sglang docker-build-ollama docker-push-vllm docker-push-sglang docker-push-ollama

docker-build: docker-build-vllm docker-build-sglang docker-build-ollama

docker-push: docker-push-vllm docker-push-sglang docker-push-ollama

docker-build-vllm:
	docker build -t $(REGISTRY)/vllm:$(VLLM_TAG) vLLM

docker-build-sglang:
	docker build -t $(REGISTRY)/sglang:$(SGLANG_TAG) SGLang

docker-build-ollama:
	docker build -t $(REGISTRY)/ollama:$(OLLAMA_TAG) Ollama

docker-push-vllm:
	docker push $(REGISTRY)/vllm:$(VLLM_TAG)

docker-push-sglang:
	docker push $(REGISTRY)/sglang:$(SGLANG_TAG)

docker-push-ollama:
	docker push $(REGISTRY)/ollama:$(OLLAMA_TAG)
