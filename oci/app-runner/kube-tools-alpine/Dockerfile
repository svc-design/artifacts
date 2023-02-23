FROM alpine:latest
MAINTAINER shenlan xz@onwalk.net

RUN echo 'https://dl-cdn.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories
RUN apk add --update --no-cache openssh apache2-utils bash wget make curl jq py3-pip unzip zip git ansible kubectl ca-certificates make && pip3 install jinja2 hvac python-hcl2

RUN wget https://mirrors.onwalk.net/tools/linux-amd64/gauth.tar.gz && tar -xvpf gauth.tar.gz -C /usr/bin/ && chmod 755 /usr/bin/gauth
RUN wget https://mirrors.onwalk.net/tools/linux-amd64/gitleaks_8.8.5_linux_x64.tar.gz && tar -xvpf gitleaks_8.8.5_linux_x64.tar.gz && cp gitleaks /usr/bin/ && chmod 755 /usr/bin/gitleaks
RUN wget https://mirrors.onwalk.net/tools/linux-amd64/helm.tar.gz && \
tar -xvpf helm.tar.gz -C /usr/local/bin/ && \
chmod 755 /usr/local/bin/helm && \
helm plugin install https://github.com/chartmuseum/helm-push.git 
ADD ca.crt /usr/share/ca-certificates/mozilla/Lets_Encrypt_ca.crt
RUN echo "mozilla/Lets_Encrypt_ca.crt" >> /etc/ca-certificates.conf && update-ca-certificates

CMD ["/bin/sh"]
