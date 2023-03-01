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
RUN curl -Lo /usr/bin/jf https://api.bintray.com/content/jfrog/jfrog-cli-go/\$latest/jfrog-cli-linux-amd64/jfrog?bt_package=jfrog-cli-linux-amd64
RUN chmod +x /usr/bin/jf

CMD ["/bin/sh"]
