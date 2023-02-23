FROM alpine:latest
MAINTAINER shenlan xz@onwalk.net

ENV VERSION=3.11.1
ENV BASE_URL="https://get.helm.sh"

ADD ca.crt /usr/share/ca-certificates/mozilla/Lets_Encrypt_ca.crt
RUN echo "mozilla/Lets_Encrypt_ca.crt" >> /etc/ca-certificates.conf && update-ca-certificates

RUN case `uname -m` in \
        armv7l) ARCH=arm; ;; \
        s390x) ARCH=s390x; ;; \
        x86_64) ARCH=amd64; ;; \
        aarch64) ARCH=arm64; ;; \
        ppc64le) ARCH=ppc64le; ;; \
        *) echo "un-supported arch, exit ..."; exit 1; ;; \
    esac && \
    apk add --update --no-cache openssh bash wget make curl jq unzip zip git ca-certificates && \
    wget ${BASE_URL}/helm-v${VERSION}-linux-${ARCH}.tar.gz -O - | tar -xz && \
    mv linux-${ARCH}/helm /usr/bin/helm && \
    chmod +x /usr/bin/helm && \
    rm -rf linux-${ARCH} && \
    chmod 755 /usr//bin/helm && \
    helm plugin install https://github.com/chartmuseum/helm-push.git

CMD ["/bin/sh"]
