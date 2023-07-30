FROM artifact.onwalk.net/devops/eksctl:latest as eksctl
FROM artifact.onwalk.net/devops/terraform:latest as terraform
FROM artifact.onwalk.net/devops/terragrunt:latest as terragrunt
FROM artifact.onwalk.net/base/alpine-awscli-python3:latest as prod

ENV KUBECTL_VERSION=1.19.3
ENV HELMCTL_VERSION=3.11.1
ENV HELMCTL_BASE_URL="https://get.helm.sh"

COPY --from=eksctl /usr/local/bin/eksctl /bin/
COPY --from=terraform /bin/terraform /bin/
COPY --from=terragrunt /usr/local/bin/terragrunt /bin/

# install helm in apline
RUN case `uname -m` in                    \
        x86_64) ARCH=amd64;            ;; \
        aarch64) ARCH=arm64;           ;; \
        loongarch64) ARCH=loongarch64; ;; \
        *) echo "un-supported arch, exit ..."; exit 1; ;; \
    esac && wget ${HELMCTL_BASE_URL}/helm-v${HELMCTL_VERSION}-linux-${ARCH}.tar.gz -O - | tar -xz && mv linux-${ARCH}/helm /usr/bin/helm && chmod +x /usr/bin/helm && rm -rf linux-${ARCH} && chmod 755 /usr//bin/helm

# install kubectl in apline
RUN wget -O /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl &&   chmod +x /usr/local/bin/kubectl

# make terraform plugin cache
ADD provider.tf /tmp/provider-cache.tf
RUN mkdir -p $HOME/.terraform.d/plugins && mkdir -pv /data/terraform/ && \
    cd /tmp && terraform init && mv .terraform/providers/* $HOME/.terraform.d/plugins && terraform providers mirror /data/terraform/ && \
    rm -rf .terraform && rm -rf provider-cache.tf .terraform.lock.hcl
COPY .terraformrc /root/

ENTRYPOINT ["/bin/sh", "-c"]
