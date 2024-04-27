# Use the official Alpine-based Go image
FROM golang:1.18-alpine

# Set the working directory
WORKDIR /src

# Install Git and other dependencies necessary for your environment
RUN apk update && apk add --no-cache git bash wget

# Install gitleaks using binary installation
RUN wget https://mirrors.onwalk.net/tools/gitleaks_8.2.4_linux_x64.tar.gz \
    && tar -xf gitleaks_8.2.4_linux_x64.tar.gz \
    && mv gitleaks /usr/bin/ \
    && rm gitleaks_8.2.4_linux_x64.tar.gz

# Install Go lint tools
RUN go install golang.org/x/lint/golint@latest

# Set the entry point to bash
ENTRYPOINT ["/bin/bash"]
