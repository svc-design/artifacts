# Build AWS Cli image for alpine
FROM artifact.onwalk.net/base/alpine-awscli:2.6.1
LABEL maintainer="Haitao Pan <manbuzhe2009@qq.com>"

# install python3
RUN apk add --update --no-cache openssh bash wget make curl jq unzip zip git python3 py3-pip unzip && \
    pip install --upgrade pip --user && pip install pyyaml boto3 Jinja2

ENTRYPOINT ["sh"]
