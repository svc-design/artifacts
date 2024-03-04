FROM alpine:3.12

# Install system dependencies
RUN apk add --no-cache \
    python3 \
    py3-pip

# Install yamllint
RUN pip3 install yamllint

# Set work directory
WORKDIR /src

# Define an entrypoint
ENTRYPOINT ["/bin/sh"]
