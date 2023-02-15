FROM infracost/infracost:latest as finops

FROM hashicorp/terraform:latest as builder

# Build IAC Runner
FROM artifact.onwalk.net/k8s/alpine-glibc:2.34 as prod
LABEL maintainer="Haitao Pan <xz@onwalk.net>"

ARG AWSCLI_VERSION=2.6.1

RUN apk add --update --no-cache ca-certificates openssl openssh-client git bash wget make curl jq py3-pip unzip zip && \
    curl -sL https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWSCLI_VERSION}.zip -o awscliv2.zip \
    && unzip awscliv2.zip && \
    aws/install && \
    rm -rf awscliv2.zip \
           aws \
           /usr/local/aws-cli/v2/current/dist/aws_completer \
           /usr/local/aws-cli/v2/current/dist/awscli/data/ac.index \
           /usr/local/aws-cli/v2/current/dist/awscli/examples \
           glibc-*.apk && \
    find /usr/local/aws-cli/v2/current/dist/awscli/botocore/data -name examples-1.json -delete && \
    mkdir -pv /root/.terraform.d/plugin-cache && \
    pip3 install jinja2 hvac python-hcl2      && \
    wget https://mirrors.onwalk.net/tools/linux-amd64/gauth.tar.gz && tar -xvpf gauth.tar.gz -C /usr/bin/ && chmod 755 /usr/bin/gauth && \
    wget https://mirrors.onwalk.net/tools/linux-amd64/gitleaks_8.8.5_linux_x64.tar.gz && tar -xvpf gitleaks_8.8.5_linux_x64.tar.gz && cp gitleaks /usr/bin/ && chmod 755 /usr/bin/gitleaks && \
    apk --no-cache del binutils curl && \
    rm -rf /var/cache/apk/*

# add pre-cost tools 
COPY --from=builder /usr/bin/terraform /usr/bin/
COPY --from=finops /usr/bin/terragrunt /usr/bin/
COPY --from=finops /usr/bin/infracost /usr/bin/
RUN mkdir -pv /root/.config/infracost/
COPY credentials.yml /root/.config/infracost/
RUN infracost configure get api_key

# init terraform provider mirror
COPY main.tf .
RUN mkdir -pv /data/terraform/
RUN terraform providers mirror /data/terraform/ && rm -f main.tf .terraform.lock.hcl
COPY .terraformrc /root/

ENTRYPOINT ["terraform"]
