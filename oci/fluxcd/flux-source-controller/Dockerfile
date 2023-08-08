FROM ghcr.io/fluxcd/source-controller:v0.36.0 as build

FROM artifact.onwalk.net/base/alpine:latest as prod

ARG TARGETPLATFORM
RUN apk --no-cache add ca-certificates && update-ca-certificates
COPY --from=build /usr/local/bin/source-controller /usr/local/bin/
USER 65534:65534

ENTRYPOINT [ "source-controller" ]
