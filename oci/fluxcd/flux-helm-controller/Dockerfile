FROM ghcr.io/fluxcd/helm-controller:v0.31.1 as build

FROM artifact.onwalk.net/base/alpine:latest as prod
LABEL org.opencontainers.image.source="https://github.com/fluxcd/helm-controller"
RUN apk add --no-cache ca-certificates tini
COPY --from=build /usr/local/bin/helm-controller /usr/local/bin/
USER 65534:65534

ENTRYPOINT [ "/sbin/tini", "--", "helm-controller" ]
