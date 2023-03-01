FROM gcr.io/kaniko-project/executor AS kaniko
FROM artifact.onwalk.net/k8s/alpine-glibc:2.34 AS prod

MAINTAINER shenlan xz@onwalk.net

# add kaniko tools
COPY --from=kaniko /kaniko/executor /kaniko/executor
COPY --from=kaniko /kaniko/docker-credential-gcr /kaniko/docker-credential-gcr
COPY --from=kaniko /kaniko/docker-credential-ecr-login /kaniko/docker-credential-ecr-login
COPY --from=kaniko /kaniko/docker-credential-acr /kaniko/docker-credential-acr
COPY --from=kaniko /etc/nsswitch.conf /etc/nsswitch.conf
COPY --from=kaniko /kaniko/.docker /kaniko/.docker

ENV PATH $PATH:/usr/local/bin:/kaniko
ENV DOCKER_CONFIG /kaniko/.docker/

# add jfrog cli
RUN curl -Lo /usr/bin/jf https://api.bintray.com/content/jfrog/jfrog-cli-go/\$latest/jfrog-cli-linux-amd64/jfrog?bt_package=jfrog-cli-linux-amd64
RUN chmod +x /usr/bin/jf

CMD ["/bin/sh"]
