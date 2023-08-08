FROM ghcr.io/fluxcd/image-automation-controller:v0.31.0 as build

FROM artifact.onwalk.net/base/alpine:latest as prod
COPY --from=build /usr/local/bin/image-automation-controller /usr/local/bin/

USER 65534:65534
ENTRYPOINT [ "image-automation-controller" ]
