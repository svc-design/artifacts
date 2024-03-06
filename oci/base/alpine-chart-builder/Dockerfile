FROM alpine:latest
MAINTAINER Haitao Pan manbuzhe2008@gmail.com

ENV VERSION=3.11.1
ENV BASE_URL="https://get.helm.sh"

RUN case `uname -m` in \
        x86_64) ARCH=amd64; ;; \
        aarch64) ARCH=arm64; ;; \
        *) echo "un-supported arch, exit ..."; exit 1; ;; \
    esac && \
    apk add --update --no-cache openssh bash wget make curl jq unzip zip git ca-certificates && \
    wget ${BASE_URL}/helm-v${VERSION}-linux-${ARCH}.tar.gz -O - | tar -xz && \
    mv linux-${ARCH}/helm /usr/bin/helm && \
    chmod +x /usr/bin/helm && \
    rm -rf linux-${ARCH} && \
    chmod 755 /usr//bin/helm && \
    helm plugin install https://github.com/chartmuseum/helm-push.git && \
    helm plugin install https://github.com/belitre/helm-push-artifactory-plugin.git --version v1.0.2

#ADD ca.crt /usr/share/ca-certificates/mozilla/Lets_Encrypt_ca.crt
#RUN echo "mozilla/Lets_Encrypt_ca.crt" >> /etc/ca-certificates.conf && update-ca-certificates

CMD ["/bin/sh"]