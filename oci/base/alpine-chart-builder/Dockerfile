FROM alpine:latest
MAINTAINER <manbuzhe2008@gmail.com>

ENV VERSION=3.13.3
ENV BASE_URL="https://get.helm.sh"
ENV KUBECTL_VERSION="v1.21.0"
ENV HELMFILE_BASE_URL="https://github.com/helmfile/helmfile/releases/download/"
ENV HELMFILE_VERSION="0.162.0"

USER root

RUN apk add --update --no-cache openssh bash wget make curl jq unzip zip git ca-certificates
RUN case `uname -m` in \
        aarch64) ARCH=arm64; ;; \
        *) ARCH=amd64;       ;; \
    esac && \
    wget -qO /usr/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl && chmod +x /usr/bin/kubectl ; \
    wget ${BASE_URL}/helm-v${VERSION}-linux-${ARCH}.tar.gz -O - | tar -xz && mv linux-${ARCH}/helm /usr/bin/helm && chmod +x /usr/bin/helm                        ; \
    helm plugin install https://github.com/databus23/helm-diff                                                                 ; \
    helm plugin install https://github.com/chartmuseum/helm-push.git                                                           ; \
    helm plugin install https://github.com/belitre/helm-push-artifactory-plugin.git --version v1.0.2                           ; \
    wget https://github.com/helmfile/helmfile/releases/download/v0.162.0/helmfile_0.162.0_linux_amd64.tar.gz && tar -xvpf helmfile_0.162.0_linux_amd64.tar.gz && mv helmfile /usr/bin/helmfile && chmod +x /usr/bin/helmfile ; \
    helmfile init --force         ; \
    rm -rf *.tar.gz || true

#ADD ca.crt /usr/share/ca-certificates/mozilla/Lets_Encrypt_ca.crt
#RUN echo "mozilla/Lets_Encrypt_ca.crt" >> /etc/ca-certificates.conf && update-ca-certificates

CMD ["/bin/sh"]
