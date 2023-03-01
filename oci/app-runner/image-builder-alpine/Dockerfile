FROM gcr.io/kaniko-project/executor:debug AS kaniko
FROM artifact.onwalk.net/k8s/alpine-glibc:2.34 AS prod
MAINTAINER shenlan xz@onwalk.net

ENV PATH $PATH:/usr/local/bin:/kaniko
ENV DOCKER_CONFIG /kaniko/.docker/

RUN apk --update add  \
                 bash \
                 curl \
                 git  \
                 jq   \
                 npm

# add kaniko tools
COPY --from=kaniko /etc/nsswitch.conf /etc/nsswitch.conf
COPY --from=kaniko /kaniko/executor /kaniko/executor


# add jfrog cli
RUN curl -Lo /usr/bin/jf https://mirrors.onwalk.net/tools/linux-amd64/jf && chmod +x /usr/bin/jf

CMD ["/bin/sh"]
