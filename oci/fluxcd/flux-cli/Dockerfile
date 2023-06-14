FROM ghcr.io/fluxcd/flux-cli:v0.31.3 as build

FROM artifact.onwalk.net/public/alpine:latest as prod
COPY --from=build /usr/local/bin/kubectl /usr/local/bin/
COPY --from=build /usr/local/bin/flux /usr/local/bin/
USER 65534:65534

ENTRYPOINT [ "flux" ]
