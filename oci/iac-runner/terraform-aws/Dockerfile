FROM artifact.onwalk.net/public/terraform:latest as builder

# Build IAC Runner
FROM artifact.onwalk.net/public/alpine-awscli-python3:latest as release

ENV KUBECTL_VERSION=1.19.3

COPY --from=builder /bin/terraform /bin/

# install kubectl in apline
RUN wget -O /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl &&   chmod +x /usr/local/bin/kubectl

# make terraform plugin cache
COPY provider-cache.tf /tmp/provider-cache.tf
RUN mkdir -pv $HOME/.terraform.d/plugins                 && \
    cd /tmp  && terraform init                           && \
    mv .terraform/providers/* $HOME/.terraform.d/plugins && \
    rm -rf .terraform && rm -rf provider-cache.tf
# config terraform cli
# ENV TF_CLI_ARGS_init="-plugin-dir=$HOME/.terraform.d/plugins"

# install python3 
# RUN apk --no-cache add python3 py3-pip

# packages for eks-environment/kubernetes/addon.sh
RUN pip install --upgrade pip --user && \
    pip install pyyaml

ENTRYPOINT ["/bin/sh", "-c"]
