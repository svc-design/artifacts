# Build AWS Cli image for alpine
FROM artifact.onwalk.net/public/alpine-glibc:2.34
LABEL maintainer="Haitao Pan <manbuzhe2009@qq.com>"

ARG AWSCLI_VERSION=2.6.1

RUN apk add --update --no-cache ca-certificates curl bash py3-pip unzip && \
    curl -sL https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWSCLI_VERSION}.zip -o awscliv2.zip \
    && unzip awscliv2.zip && \
    aws/install && \
    rm -rf awscliv2.zip \
           aws \
           /usr/local/aws-cli/v2/current/dist/aws_completer \
           /usr/local/aws-cli/v2/current/dist/awscli/data/ac.index \
           /usr/local/aws-cli/v2/current/dist/awscli/examples \
           glibc-*.apk && \
    find /usr/local/aws-cli/v2/current/dist/awscli/botocore/data -name examples-1.json -delete && \
    rm -rf /var/cache/apk/*

ENTRYPOINT ["sh"]
