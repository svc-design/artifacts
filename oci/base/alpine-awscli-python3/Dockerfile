FROM alpine:3.18.3
LABEL maintainer="Haitao Pan <manbuzhe2009@qq.com>"

ARG GLIBC_VERSION=2.34-r0
ARG AWSCLI_VERSION=2.6.1

# install Glibc compatibility for alpine
RUN apk add --update --no-cache curl binutils \
    && curl -sL https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub -o /etc/apk/keys/sgerrand.rsa.pub \
    && curl -sLO https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-${GLIBC_VERSION}.apk \
    && curl -sLO https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-bin-${GLIBC_VERSION}.apk \
    && curl -sLO https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-i18n-${GLIBC_VERSION}.apk \
    && apk add --no-cache --force-overwrite \
       glibc-${GLIBC_VERSION}.apk           \
       glibc-bin-${GLIBC_VERSION}.apk       \
       glibc-i18n-${GLIBC_VERSION}.apk      \
    && apk fix --force-overwrite alpine-baselayout-data \
    && /usr/glibc-compat/bin/localedef -i en_US -f UTF-8 en_US.UTF-8 \
    && rm -rf glibc-*.apk \
    && rm -rf /var/cache/apk/*

# Install AWS CLI v2 for alpine
RUN apk add --update --no-cache ca-certificates curl bash py3-pip unzip && \
    curl -sL https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWSCLI_VERSION}.zip -o awscliv2.zip && \
    unzip awscliv2.zip && \
    aws/install        && \
    rm -rf awscliv2.zip \
           aws \
           /usr/local/aws-cli/v2/current/dist/aws_completer \
           /usr/local/aws-cli/v2/current/dist/awscli/data/ac.index \
           /usr/local/aws-cli/v2/current/dist/awscli/examples \
           glibc-*.apk && \
    find /usr/local/aws-cli/v2/current/dist/awscli/botocore/data -name examples-1.json -delete && \
    rm -rf /var/cache/apk/*

# install python3
RUN apk add --update --no-cache curl bash curl wget make jq git openssh python3 py3-pip zip unzip ca-certificates && \
    pip install --upgrade pip --user && pip install pyyaml boto3 Jinja2 && \
    rm -rf /var/cache/apk/*

# Add Roche ca certs
RUN cd /usr/local/share/ca-certificates/ && \
    curl -k https://certinfo.roche.com/rootcerts/Roche%20Root%20CA%201.crt -o RocheRootCA1.cer    && \
    curl -k https://certinfo.roche.com/rootcerts/RocheEnterpriseCA1.crt -o RocheEnterpriseCA1.cer && \
    curl -k https://certinfo.roche.com/rootcerts/Roche%20Root%20CA%201%20-%20G2.crt -o RocheRootCA1-G2.cer.cer         && \
    curl -k https://certinfo.roche.com/rootcerts/Roche%20Enterprise%20CA%201%20-%20G2.crt -o RocheEnterpriseCA1-G2.crt && \
    curl -k https://certinfo.roche.com/rootcerts/Roche%20G3%20Root%20CA.crt -o RocheG3RootCA.crt                       && \
    curl -k https://certinfo.roche.com/rootcerts/Roche%20G3%20Issuing%20CA%201.crt -o RocheG3IssuingCA1.crt            && \
    curl -k https://certinfo.roche.com/rootcerts/Roche%20G3%20Issuing%20CA%202.crt -o RocheG3IssuingCA2.crt            && \
    curl -k https://certinfo.roche.com/rootcerts/Roche%20G3%20Issuing%20CA%203.crt -o RocheG3IssuingCA3.crt            && \
    curl -k https://certinfo.roche.com/rootcerts/Roche%20G3%20Issuing%20CA%204.crt -o RocheG3IssuingCA4.crt            && \
    update-ca-certificates

ENTRYPOINT ["sh"]
