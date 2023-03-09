FROM debian:11-slim AS builder
ARG PULUMI_VERSION
RUN apt-get update -y && \
  apt-get upgrade -y && \
  apt-get install -y \
  curl \
  build-essential \
  git

# Install the Pulumi SDK, including the CLI and language runtimes.
RUN curl -fsSL https://get.pulumi.com/ | bash -s -- --version $PULUMI_VERSION


FROM artifact.onwalk.net/public/alpine-glibc:2.34 as prod
LABEL maintainer="Haitao Pan <xz@onwalk.net>"

ENV PATH "/pulumi/bin:${PATH}"

WORKDIR /pulumi
COPY --from=builder /root/.pulumi/bin bin
RUN apk add --update --no-cache ca-certificates openssh-client git bash wget make curl jq py3-pip unzip zip

CMD ["bash"]
