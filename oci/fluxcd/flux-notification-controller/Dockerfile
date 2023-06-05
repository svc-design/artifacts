FROM ghcr.io/fluxcd/notification-controller:v0.33.0 as build

FROM artifact.onwalk.net/public/alpine:latest as prod

LABEL org.opencontainers.image.source="https://github.com/fluxcd/notification-controller"
RUN apk add --no-cache ca-certificates tini
COPY --from=build /usr/local/bin/notification-controller /usr/local/bin/
USER 65534:65534

ENTRYPOINT [ "/sbin/tini", "--", "notification-controller" ]
