FROM hashicorp/terraform:latest as builder
FROM infracost/infracost:latest as finops

# Build IAC Runner
FROM artifact.onwalk.net/k8s/alpine-awscli:2.6.1 as prod
LABEL maintainer="Haitao Pan <xz@onwalk.net>"

ENV KUBECTL_VERSION=1.19.3

RUN apk add --update --no-cache ca-certificates openssl openssh-client git bash wget make curl jq unzip zip python3 py3-pip && \
    pip3 install --upgrade pip --user && \
    pip3 install jinja2 hvac python-hcl2 pyyaml && \
    wget https://mirrors.onwalk.net/tools/linux-amd64/gauth.tar.gz && tar -xvpf gauth.tar.gz -C /usr/bin/ && chmod 755 /usr/bin/gauth && \
    wget -O /usr/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl & chmod +x /usr/bin/kubectl && \
    wget https://mirrors.onwalk.net/tools/linux-amd64/gitleaks_8.8.5_linux_x64.tar.gz && tar -xvpf gitleaks_8.8.5_linux_x64.tar.gz && cp gitleaks /usr/bin/ && chmod 755 /usr/bin/gitleaks && \
    apk --no-cache del binutils make && \
    rm -rf /var/cache/apk/*
    mkdir -pv /root/.terraform.d/plugin-cache && \

# add iac tools 
COPY --from=builder /bin/terraform /bin/

# add pre-cost tools 
COPY --from=finops /usr/bin/terragrunt /usr/bin/
COPY --from=finops /usr/bin/infracost /usr/bin/

# config pre-cost tools 
RUN mkdir -pv /root/.config/infracost/
COPY credentials.yml /root/.config/infracost/
RUN infracost configure get api_key

# init terraform provider cache
COPY main.tf .
RUN mkdir -pv /data/terraform/
RUN terraform providers mirror /data/terraform/ && rm -f main.tf .terraform.lock.hcl
COPY .terraformrc /root/

ENTRYPOINT ["/bin/sh", "-c"]
