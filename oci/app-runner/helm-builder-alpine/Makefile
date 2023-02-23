all:
	docker build --network host --no-cache --build-arg VERSION=3.6.0 -t  artifact.onwalk.net/k8s/ci-runner:v3.6.2 .
	docker push artifact.onwalk.net/k8s/ci-runner:v3.6.2
