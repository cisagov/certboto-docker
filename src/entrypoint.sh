#!/bin/sh

set -o nounset
set -o errexit
# Sha-bang cannot be /bin/bash (not available), but
# the container's /bin/sh does support pipefail.
# shellcheck disable=SC2039
set -o pipefail

if [ "$1" = "--version" ]; then
  awk '{print $3}' < version.txt | tr -d \"
  certbot --version
  exit 0
fi

# Allow users to get help without bucket syncing
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  certbot --help
  exit $?
fi

ACME_CONFIG_ROOT=/etc/letsencrypt

echo "Syncing certbot configs from ${BUCKET_NAME}"
AWS_PROFILE=${BUCKET_PROFILE} aws s3 sync --no-progress "s3://${BUCKET_NAME}" \
  ${ACME_CONFIG_ROOT} | grep -v "^download:" || true

echo "Rebuilding symlinks in ${ACME_CONFIG_ROOT}"
./rebuild-symlinks.py --log-level warning ${ACME_CONFIG_ROOT}

echo "Running: certbot --dns-route53 $*"
# shellcheck disable=SC2048,SC2086
AWS_PROFILE=${DNS_PROFILE} certbot --dns-route53 $*

echo "Syncing certbot configs to ${BUCKET_NAME}"
AWS_PROFILE=${BUCKET_PROFILE} aws s3 sync --delete ${ACME_CONFIG_ROOT} "s3://${BUCKET_NAME}"
