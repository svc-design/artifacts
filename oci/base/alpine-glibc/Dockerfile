FROM alpine:3.18.3 
LABEL maintainer="Haitao Pan <manbuzhe2009@qq.com>"

ARG GLIBC_VERSION=2.34-r0

# install glibc compatibility for alpine
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

#RUN cd /usr/local/share/ca-certificates/ && curl -k https://extra-ca.crt -o ca.cer && update-ca-certificates

ENTRYPOINT ["bash"]
