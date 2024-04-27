FROM docker:dind

# Update APK repositories, upgrade the existing system, and install required packages
RUN apk update && \
    apk upgrade && \
    apk add --no-cache git bash curl

# Set environment variables for Docker daemon to listen on tcp and to disable TLS (adjust based on your security requirements)
ENV DOCKER_TLS_CERTDIR=""
ENV DOCKER_HOST=tcp://localhost:2375
COPY fetch_build_tag.sh /opt/

# Expose the default Docker daemon port
EXPOSE 2375

# Set an entrypoint that starts the Docker daemon
ENTRYPOINT ["dockerd-entrypoint.sh"]

# By default, run the Docker daemon (additional command-line options can be provided at runtime)
CMD []
