FROM ghcr.io/fluxcd/kustomize-controller:v0.35.0 as build

FROM artifact.onwalk.net/public/alpine:latest as prod

RUN apk add --no-cache ca-certificates tini git openssh-client && apk add --no-cache gnupg --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main

COPY --from=build /usr/local/bin/kustomize-controller /usr/local/bin/
USER 65534:65534
ENV GNUPGHOME=/tmp

ENTRYPOINT [ "/sbin/tini", "--", "kustomize-controller" ]
