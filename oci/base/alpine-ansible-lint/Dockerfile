FROM alpine:latest

# Install system dependencies
RUN apk add --no-cache bash git python3 py3-pip jq && \
    pip3 install --upgrade pip                     && \
    pip3 install hvac jinja2 ansible ansible-lint  && \
    ansible-galaxy collection install community.hashi_vault

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]
