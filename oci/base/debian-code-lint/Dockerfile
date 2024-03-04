FROM debian:buster

# Install necessary system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    python3 \
    python3-pip \
    golang-go \
    nodejs \
    npm \
    libyaml-dev \
    libffi-dev

# Install pip and Ansible
RUN pip3 install --upgrade pip
RUN pip3 install ansible ansible-lint

# Set up Go, install Go dependencies, and clear Go package cache
RUN go get -u golang.org/x/lint/golint
RUN rm -rf /go/pkg/*

# Install yamllint
RUN pip3 install yamllint

# Set up Node.js and npm, install eslint and React plugin
RUN npm install -g eslint eslint-plugin-react

# Ensure the tools are in the PATH
ENV PATH="/go/bin:${PATH}"

# Set work directory
WORKDIR /src

# Define an entrypoint
ENTRYPOINT ["/bin/bash"]
