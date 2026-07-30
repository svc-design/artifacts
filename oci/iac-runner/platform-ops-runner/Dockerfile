FROM alpine:3.19 AS base

ENV TERRAFORM_VERSION=1.15.8
ENV VAULT_VERSION=2.0.3
ENV ANSIBLE_VERSION=14.0.0

RUN apk add --no-cache \
    python3 \
    py3-pip \
    py3-yaml \
    py3-jinja2 \
    bash \
    curl \
    jq \
    git \
    openssh-client \
    ca-certificates \
    make \
    tar \
    gzip \
    bind-tools \
    rsync

# Install Terraform CLI
RUN case $(uname -m) in \
        x86_64) ARCH=amd64 ;; \
        aarch64) ARCH=arm64 ;; \
        *) echo "Unsupported architecture" && exit 1 ;; \
    esac && \
    curl -fsSL https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip -o terraform.zip && \
    unzip terraform.zip -d /usr/local/bin/ && \
    rm -f terraform.zip && \
    chmod +x /usr/local/bin/terraform

# Install Vault CLI
RUN case $(uname -m) in \
        x86_64) ARCH=amd64 ;; \
        aarch64) ARCH=arm64 ;; \
        *) echo "Unsupported architecture" && exit 1 ;; \
    esac && \
    curl -fsSL https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${ARCH}.zip -o vault.zip && \
    unzip vault.zip -d /usr/local/bin/ && \
    rm -f vault.zip && \
    chmod +x /usr/local/bin/vault

# Install Ansible and Python dependencies
RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir --upgrade pip && \
    /opt/venv/bin/pip install --no-cache-dir \
        ansible=="${ANSIBLE_VERSION}" \
        hvac \
        netaddr \
        jmespath \
        requests

ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /workspace
ENTRYPOINT ["/bin/bash", "-c"]
