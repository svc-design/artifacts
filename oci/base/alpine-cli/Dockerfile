# Build alpine base Imagec with Bash
FROM artifact.onwalk.net/base/alpine:latest
LABEL maintainer="Haitao Pan <manbuzhe2009@qq.com>"

ARG AWSCLI_VERSION=2.6.1

RUN apk add --update --no-cache ca-certificates curl bash py3-pip unzip && rm -rf /var/cache/apk/*

ENTRYPOINT ["sh"]
