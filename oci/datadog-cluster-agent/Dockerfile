oci/datadog-cluster-agent/Dockerfile########################################
# Preparation stage: layout and chmods #
########################################

FROM artifact.onwalk.net/k8s/datadog/cluster-agent:latest as builder

FROM builder AS nosys-seccomp
COPY nosys-seccomp/nosys.c   /tmp/nosys.c
COPY nosys-seccomp/nosys.sym /tmp/nosys.sym
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt install --no-install-recommends -y gcc libc6-dev libseccomp-dev
RUN gcc -pipe -Wall -Wextra -O2 -shared -fPIC -Wl,--version-script=/tmp/nosys.sym -o /tmp/nosys.so /tmp/nosys.c -lseccomp

####################################
# Actual docker image construction #
####################################

FROM artifact.onwalk.net/public/ubuntu:22.04

LABEL maintainer "Datadog <package@datadoghq.com>"

ARG CIBUILD

ENV PATH="/opt/datadog-agent/bin/:$PATH" \
    DOCKER_DD_AGENT="true" \
    # Allow User Group to exec the secret backend script.
    DD_SECRET_BACKEND_COMMAND_ALLOW_GROUP_EXEC_PERM="true"

RUN apt-get update \
    && apt full-upgrade -y \
    && apt-get install --no-install-recommends -y ca-certificates curl libseccomp2 tzdata \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=builder /output /

RUN adduser --system --no-create-home --disabled-password --ingroup root dd-agent \
    && mkdir -p /var/log/datadog/ /conf.d \
    && touch /var/log/datadog/.placeholder \
    && touch /tmp/.placeholder \
    && chown -R dd-agent:root /etc/datadog-agent/ /var/log/datadog/ /conf.d /tmp/ \
    && chmod g+r,g+w,g+X -R /etc/datadog-agent/ /var/log/datadog/ /conf.d /tmp/

# Ensure the glibc doesn't try to call syscalls that may not be supported
COPY --from=nosys-seccomp /tmp/nosys.so /lib/x86_64-linux-gnu/nosys.so
ENV LD_PRELOAD=/lib/x86_64-linux-gnu/nosys.so

# Incompatible with the custom metrics API on port 443
# Set DD_EXTERNAL_METRICS_PROVIDER_PORT to a higher value to run as non-root
# USER dd-agent

# Leave following directories RW to allow use of readonly rootfs
VOLUME ["/etc/datadog-agent", "/var/log/datadog", "/tmp"]

ENTRYPOINT ["/entrypoint.sh"]

# No docker healthcheck, use a HTTP check
# on port 5005 and/or 443 on Kubernetes

CMD ["datadog-cluster-agent", "start"]
