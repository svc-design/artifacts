#!/bin/sh
# required by Jenkins Docker plugin: https://github.com/docker-library/official-images#consistency

set -x
exec "$@"
