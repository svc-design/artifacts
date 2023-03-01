FROM gcr.io/kaniko-project/executor:v1.9.1-debug as builder

FROM artifact.onwalk.net/k8s/alpine-glibc:2.34 as prod
MAINTAINER shenlan xz@onwalk.net

# add kaniko buider
COPY --from=builder /kaniko/  /

# add jfrog cli
RUN curl -Lo /usr/bin/jf https://api.bintray.com/content/jfrog/jfrog-cli-go/\$latest/jfrog-cli-linux-amd64/jfrog?bt_package=jfrog-cli-linux-amd64
RUN chmod +x /usr/bin/jf

CMD ["/bin/sh"]
