FROM alpine:3.18.3
MAINTAINER shenlan manbuzhe2009@qq.com

USER root

ADD ca.crt /usr/share/ca-certificates/mozilla/Lets_Encrypt_ca.crt
RUN echo "mozilla/Lets_Encrypt_ca.crt" >> /etc/ca-certificates.conf

RUN apk add --no-cache curl ca-certificates
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

ENTRYPOINT [ "/bin/sh" ]
