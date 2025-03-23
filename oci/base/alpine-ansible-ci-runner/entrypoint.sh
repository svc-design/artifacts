#!/bin/sh
# required by Jenkins Docker plugin: https://github.com/docker-library/official-images#consistency

# Print a message
echo "Ansible Docker container is ready to run playbooks..."

# Execute the command passed to the Docker container
exec "$@"
