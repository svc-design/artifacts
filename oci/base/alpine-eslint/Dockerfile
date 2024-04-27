FROM node:lts-alpine

# Install bash, git, and curl
RUN apk add --no-cache bash git curl && \
    npm install -g eslint            && \
    npm install -g next              && \
    npm install -g jest              && \
    npm install -g ts-node           && \
    npm install -g typescript        && \
    npm install -g next-translate    && \
    npm install -g next-translate-plugin

# Install gitleaks using binary installation
RUN wget https://mirrors.onwalk.net/tools/gitleaks_8.2.4_linux_x64.tar.gz \
    && tar -xf gitleaks_8.2.4_linux_x64.tar.gz \
    && mv gitleaks /usr/bin/ \
    && rm gitleaks_8.2.4_linux_x64.tar.gz

# Set the working directory
WORKDIR /src

ENTRYPOINT ["/bin/bash"]
# Define the default command to start bash
CMD ["/bin/bash"]
