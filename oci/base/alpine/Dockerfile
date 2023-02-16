FROM alpine:latest
MAINTAINER shenlan xz@onwalk.net

ADD ca.crt /usr/share/ca-certificates/mozilla/Lets_Encrypt_ca.crt
RUN apk add --no-cache ca-certificates   && echo "mozilla/Lets_Encrypt_ca.crt" >> /etc/ca-certificates.conf && update-ca-certificates 

ENTRYPOINT [ "/bin/sh" ]
