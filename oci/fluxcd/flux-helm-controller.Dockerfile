FROM ghcr.io/fluxcd/helm-controller:v0.22.1 as build

FROM artifact.onwalk.net/k8s/alpine-ca:3.13 as prod
LABEL org.opencontainers.image.source="https://github.com/fluxcd/helm-controller"
RUN apk add --no-cache ca-certificates tini
COPY --from=build /usr/local/bin/helm-controller /usr/local/bin/
USER 65534:65534

ENTRYPOINT [ "/sbin/tini", "--", "helm-controller" ]
