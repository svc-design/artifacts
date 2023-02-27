# Build AWS Cli image for alpine
FROM artifact.onwalk.net/k8s/alpine-glibc-awscli:2.6.1
LABEL maintainer="Haitao Pan <manbuzhe2009@qq.com>"

# install python3
RUN apk --no-cache add python3 py3-pip

ENTRYPOINT ["sh"]
