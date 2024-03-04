# Stage 1: Build environment
FROM alpine:3.12 as builder

# Install build dependencies
RUN apk add --no-cache \
    git \
    curl \
    python3 \
    python3-dev \
    py3-pip \
    go \
    nodejs \
    npm \
    yaml-dev \
    libffi-dev \
    gcc \
    musl-dev

# Install pip and Ansible
RUN pip3 install --upgrade pip
RUN pip3 install ansible ansible-lint

# Set up Go, install Go dependencies
RUN go get -u golang.org/x/lint/golint

# Install yamllint
RUN pip3 install yamllint

# Set up Node.js and npm, install eslint and React plugin
RUN npm install -g eslint eslint-plugin-react

# Stage 2: Final image
FROM alpine:3.12

# Copy necessary files from the builder stage
COPY --from=builder /usr/bin/python3 /usr/bin/python3
COPY --from=builder /usr/lib/python3.8 /usr/lib/python3.8
COPY --from=builder /usr/bin/go /usr/bin/go
COPY --from=builder /root/go /root/go
COPY --from=builder /usr/bin/node /usr/bin/node
COPY --from=builder /usr/lib/node_modules /usr/lib/node_modules

# Create symbolic links for python and pip
RUN ln -s /usr/bin/python3 /usr/bin/python
RUN ln -s /usr/bin/python3 /usr/bin/pip

# Ensure the tools are in the PATH
ENV PATH="/root/go/bin:/usr/lib/node_modules/.bin:${PATH}"

# Set work directory
WORKDIR /src

# Define an entrypoint
ENTRYPOINT ["/bin/sh"]

