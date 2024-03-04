FROM alpine:3.12

# Install system dependencies
RUN apk add --no-cache \
    python3 \
    py3-pip

# Install flake8
RUN pip3 install flake8

# Set work directory
WORKDIR /src

# Define an entrypoint
ENTRYPOINT ["flake8"]

