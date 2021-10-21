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

certbot_args=""
use_route53=true
drop_to_shell=false

# Parse command line arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --version)
      awk '{print $3}' < version.txt | tr -d \"
      certbot --version
      exit 0
      ;;
    -h | --help) # Allow users to get help without bucket syncing
      certbot --help
      exit $?
      ;;
    --no-dns-route53)
      echo "Route53 DNS challenge disabled by --no-dns-route53 flag"
      use_route53=false
      shift
      ;;
    --shell)
      drop_to_shell=true
      shift
      ;;
    *) # add to certbot_args
      certbot_args="$certbot_args $1"
      shift
      ;;
  esac
done

ACME_CONFIG_ROOT=/etc/letsencrypt

echo "Syncing certbot configs from ${BUCKET_NAME}"
AWS_PROFILE=${BUCKET_PROFILE} aws s3 sync --no-progress "s3://${BUCKET_NAME}" \
  ${ACME_CONFIG_ROOT} | grep -v "^download:" || true

echo "Rebuilding symlinks in ${ACME_CONFIG_ROOT}"
./rebuild-symlinks.py --log-level warning ${ACME_CONFIG_ROOT}

if [ $use_route53 = true ]; then
  # Add the --dns-route53 argument to the start of our args
  certbot_args="--dns-route53 $certbot_args"
fi

if [ $drop_to_shell = true ]; then
  echo "Starting a shell as requested by argument --shell"
  echo "Certbot configs will be synchronized upon shell exit."
  echo "Would have run command: AWS_PROFILE=${DNS_PROFILE} certbot ${certbot_args}"
  /bin/sh
  echo
else
  echo "Running: certbot $certbot_args"
  # shellcheck disable=SC2048,SC2086
  AWS_PROFILE=${DNS_PROFILE} certbot $certbot_args
fi

echo "Syncing certbot configs to ${BUCKET_NAME}"
AWS_PROFILE=${BUCKET_PROFILE} aws s3 sync --delete ${ACME_CONFIG_ROOT} "s3://${BUCKET_NAME}"
