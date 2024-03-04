FROM alpine:latest

# Install Go & Git
RUN apk add --no-cache go go

# Install golint
RUN go get -u golang.org/x/lint/golint

# Ensure the tools are in the PATH
ENV PATH="/root/go/bin:${PATH}"

# Set work directory
WORKDIR /src

# Define an entrypoint
ENTRYPOINT ["golint"]
