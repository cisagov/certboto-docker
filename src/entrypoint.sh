#!/bin/sh

set -o nounset
set -o errexit
# Sha-bang cannot be /bin/bash (not available), but
# the container's /bin/sh does support pipefail.
# SC2039 has been retired in favor of SC3xxx issues.
# See: https://github.com/koalaman/shellcheck/wiki/SC2039
# See: https://github.com/koalaman/shellcheck/issues/2052
# Both the old and new codes are listed since CI is using the old code (0.7.0),
# and dev environments are using the newer version (0.7.2).
# shellcheck disable=SC2039,SC3040
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

# First argument flag --no-dns-route53 disables default use of --dns-route53
if [ "$1" = "--no-dns-route53" ]; then
  shift
  echo "Route53 DNS challenge disabled by --no-dns-route53 flag"
else
  # Add the --dns-route53 argument to the start of our args
  set -- --dns-route53 "$*"
fi

echo "Running: certbot $*"
# shellcheck disable=SC2048,SC2086
AWS_PROFILE=${DNS_PROFILE} certbot $*

echo "Syncing certbot configs to ${BUCKET_NAME}"
AWS_PROFILE=${BUCKET_PROFILE} aws s3 sync --delete ${ACME_CONFIG_ROOT} "s3://${BUCKET_NAME}"
