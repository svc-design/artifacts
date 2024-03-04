FROM alpine:3.12

# Install Node.js and npm
RUN apk add --no-cache \
    nodejs \
    npm

# Install eslint
RUN npm install -g eslint

# Set work directory
WORKDIR /src

# Define an entrypoint
ENTRYPOINT ["eslint"]
