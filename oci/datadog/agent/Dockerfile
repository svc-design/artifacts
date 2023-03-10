FROM artifact.onwalk.net/k8s/datadog/agent:7.43.1

LABEL maintainer "Datadog <package@datadoghq.com>"

ADD 99DpkgForceConf /etc/apt/apt.conf.d/99DpkgForceConf
ADD 00InstallRecommends /etc/apt/apt.conf.d/00InstallRecommends
RUN apt update && export DEBIAN_FRONTEND=noninteractive && apt install ca-certificates curl -y
RUN apt install -f && dpkg --configure -a 
RUN cd /usr/local/share/ca-certificates/ && curl http://certinfo.roche.com/rootcerts/Roche%20Root%20CA%201.cer -o RocheRootCA1.cer && \
    curl http://certinfo.roche.com/rootcerts/RocheEnterpriseCA1.cer -o RocheEnterpriseCA1.cer && \
    curl http://certinfo.roche.com/rootcerts/RocheEnterpriseCA2.cer \
                                                                    -o RocheEnterpriseCA2.cer && curl http://certinfo.roche.com/rootcerts/Roche%20Root%20CA%201%20-%20G2.crt \
                                                                    -o RocheRootCA1-G2.crt && curl http://certinfo.roche.com/rootcerts/Roche%20Enterprise%20CA%201%20-%20G2.crt \
                                                                    -o RocheEnterpriseCA1-G2.crt && curl http://certinfo.roche.com/rootcerts/Roche%20G3%20Root%20CA.crt \
                                                                    -o RocheG3RootCA.crt && curl http://certinfo.roche.com/rootcerts/Roche%20G3%20Issuing%20CA%201.crt \
                                                                    -o RocheG3IssuingCA1.crt && curl http://certinfo.roche.com/rootcerts/Roche%20G3%20Issuing%20CA%202.crt \
                                                                    -o RocheG3IssuingCA2.crt && curl http://certinfo.roche.com/rootcerts/Roche%20G3%20Issuing%20CA%203.crt \
                                                                    -o RocheG3IssuingCA3.crt && curl http://certinfo.roche.com/rootcerts/Roche%20G3%20Issuing%20CA%204.crt \
                                                                    -o RocheG3IssuingCA4.crt && update-ca-certificates

ENV LD_PRELOAD=/opt/lib/nosys.so

CMD ["/bin/entrypoint.sh"]
