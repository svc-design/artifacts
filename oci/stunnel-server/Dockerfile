FROM alpine:3.21

LABEL org.opencontainers.image.title="stunnel runtime" \
      org.opencontainers.image.description="Minimal stunnel image for PostgreSQL TLS tunnel server/client (inspired by dweomer/dockerfiles-stunnel)" \
      org.opencontainers.image.source="https://github.com/cloud-neutral-toolkit/postgresql.svc.plus"

RUN set -eux; \
    apk add --no-cache ca-certificates stunnel; \
    grep -q '^stunnel:' /etc/group || addgroup -S stunnel; \
    id -u stunnel >/dev/null 2>&1 || adduser -S -D -H -G stunnel -s /sbin/nologin stunnel; \
    mkdir -p /etc/stunnel/certs /var/run/stunnel; \
    chown -R stunnel:stunnel /etc/stunnel /var/run/stunnel; \
    cp /etc/stunnel/stunnel.conf /etc/stunnel/stunnel.conf.original || true

USER stunnel

EXPOSE 5433

# Keep the service in the foreground so logs remain container events on stderr.
ENTRYPOINT ["stunnel", "-f"]
CMD ["/etc/stunnel/stunnel.conf"]
