FROM python:latest

ENV TIME_ZONE=Asia/Shanghai                                              \
    BIN_PERM=0755                                                        \
    BIN_DIR=/usr/local/bin                                               \
    HELM_URL=https://get.helm.sh                                         \
    HELM_VERSION="v3.10.2"                                               \
    HELM_FILE_URL=https://github.com/helmfile/helmfile/releases/download \
    HELM_FILE_VERSION=0.163.1

RUN unlink /etc/localtime && ln -s /usr/share/zoneinfo/${TIME_ZONE} /etc/localtime                                                 \
    && apt-get update -y && apt-get upgrade -y                                                                                     \
    && apt-get --reinstall -y install tar curl sshpass jq git vim uuid-runtime                                                     \
    && wget ${HELM_URL}/helm-${HELM_VERSION}-linux-amd64.tar.gz -O - | tar -xz -C ${BIN_DIR} --strip-components=1 linux-amd64/helm \
    && chmod ${BIN_PERM} ${BIN_DIR}/helm                                                                                           \
    && wget ${HELM_FILE_URL}/v${HELM_FILE_VERSION}/helmfile_${HELM_FILE_VERSION}_linux_amd64.tar.gz -O - | tar -xz -C ${BIN_DIR}   \
    && chmod ${BIN_PERM} ${BIN_DIR}/helmfile                                                                                       \
    && helm plugin install https://github.com/databus23/helm-diff                                                                  \
    && rm -rf /var/lib/apt/lists/*

RUN pip install ansible ansible-lint jmespath hvac jinja2 && ansible-galaxy collection install community.hashi_vault

WORKDIR /home/${USER}

CMD $@
