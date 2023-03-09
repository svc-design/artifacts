FROM ghcr.io/fluxcd/source-controller:v0.25.9 as build

FROM artifact.onwalk.net/public/alpine-ca:3.13 as prod

ARG TARGETPLATFORM
RUN apk --no-cache add ca-certificates && update-ca-certificates
COPY --from=build /usr/local/bin/source-controller /usr/local/bin/
USER 65534:65534

ENTRYPOINT [ "source-controller" ]
