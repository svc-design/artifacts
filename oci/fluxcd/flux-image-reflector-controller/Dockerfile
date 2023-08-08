FROM ghcr.io/fluxcd/image-reflector-controller:v0.26.0 as build

FROM artifact.onwalk.net/base/alpine:latest as prod

RUN apk add --no-cache ca-certificates tini
COPY --from=build /usr/local/bin/image-reflector-controller /usr/local/bin/
USER 65534:65534

ENTRYPOINT [ "/sbin/tini", "--", "image-reflector-controller" ]
