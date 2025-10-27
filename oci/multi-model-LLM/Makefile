ORG ?= your-org
IMAGE_REGISTRY ?= ghcr.io/$(ORG)/model-serving
CHART_NAME ?= model-serving
CHART_DIR := charts/$(CHART_NAME)
VERSION ?= 0.1.0

.PHONY: docker-build docker-push helm-lint helm-package helm-push install uninstall template

docker-build:
	$(MAKE) -C ../base/cuda docker-build REGISTRY=$(IMAGE_REGISTRY)

docker-push:
	$(MAKE) -C ../base/cuda docker-push REGISTRY=$(IMAGE_REGISTRY)

helm-lint:
	helm lint $(CHART_DIR)

helm-package:
	helm package $(CHART_DIR) --version $(VERSION) --app-version $(VERSION) -d charts/

helm-push: helm-package
	helm push charts/$(CHART_NAME)-$(VERSION).tgz oci://ghcr.io/$(ORG)/helm

RELEASE ?= ms
NAMESPACE ?= llm

install:
	kubectl create ns $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install $(RELEASE) $(CHART_DIR) -n $(NAMESPACE)

uninstall:
	helm uninstall $(RELEASE) -n $(NAMESPACE) || true

template:
	helm template $(RELEASE) $(CHART_DIR)
