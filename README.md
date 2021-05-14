# certboto-docker 📜🤖☁️🐳 #

[![GitHub Build Status](https://github.com/cisagov/certboto-docker/workflows/build/badge.svg)](https://github.com/cisagov/certboto-docker/actions)
[![Total alerts](https://img.shields.io/lgtm/alerts/g/cisagov/certboto-docker.svg?logo=lgtm&logoWidth=18)](https://lgtm.com/projects/g/cisagov/certboto-docker/alerts/)
[![Language grade: Python](https://img.shields.io/lgtm/grade/python/g/cisagov/certboto-docker.svg?logo=lgtm&logoWidth=18)](https://lgtm.com/projects/g/cisagov/certboto-docker/context:python)

## Docker Image ##

[![Docker Pulls](https://img.shields.io/docker/pulls/cisagov/certboto)](https://hub.docker.com/r/cisagov/certboto)
[![Docker Image Size (latest by date)](https://img.shields.io/docker/image-size/cisagov/certboto)](https://hub.docker.com/r/cisagov/certboto)
[![Platforms](https://img.shields.io/badge/platforms-amd64%20%7C%20arm%2Fv6%20%7C%20arm%2Fv7%20%7C%20arm64%20%7C%20ppc64le%20%7C%20s390x-blue)](https://hub.docker.com/r/cisagov/certboto/tags)

Certboto combines all the convenience of [Certbot](https://certbot.eff.org)
with the cloudiness of [AWS S3 buckets](https://aws.amazon.com/s3/)
and [AWS Route53](https://aws.amazon.com/route53/)
all wrapped up in a tasty [Docker](https://www.docker.com) container.

## Usage ##

Consider using a `docker-compose.yml` file to run Certboto.
See the Install section below.

To issue a new certificate:

```console
docker-compose run certboto certonly -d lemmy.imotorhead.com
```

To renew existing certificates:

```console
docker-compose run certboto
```

For additional `certbot` commands see the help:

```console
docker-compose run certboto --help
```

To disable usage of the Route53 DNS plugin pass `--no-dns-route53` as the first
argument.  This is useful if you need to use other types of challenges.

```console
docker-compose run certboto --no-dns-route53 --manual certonly -d lemmy.imotorhead.com
```

### Install ###

Create a `docker-compose.yml` file similar to this:

```yml
---
version: "3.7"

secrets:
  credentials:
    file: /home/username/.aws/credentials

services:
  certboto:
    image: cisagov/certboto
    init: true
    restart: "no"
    environment:
      - AWS_DEFAULT_REGION=us-east-1
      - BUCKET_NAME=my-certificates
      - BUCKET_PROFILE=certsync-role
      - DNS_PROFILE=dns-role
    secrets:
      - source: credentials
        target: credentials
```

Pull `cisagov/certboto` from [Docker hub](https://hub.docker.com):

```console
docker-compose pull
```

Or build `cisagov/certboto` from source:

```console
git clone https://github.com/cisagov/certboto-docker.git
cd certboto-docker
docker-compose build --build-arg VERSION=0.0.3
```

## Environment Variables ##

| Variable      | Purpose      |
|---------------|--------------|
| AWS_DEFAULT_REGION | Default AWS region |
| BUCKET_NAME | The bucket to store the Certbot configuration |
| BUCKET_PROFILE | The profile of your `credentials` to use for bucket access.
| DNS_PROFILE | The profile of your `credentials` to use for route53 access.

## Secrets ##

| Filename      | Purpose              |
|---------------|----------------------|
| credentials   | The [AWS credentials](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) file. |

## AWS Policies ##

### Certboto Roles ###

The `BUCKET_PROFILE` should assume a role with the following policy:

```javascript
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::cert-bucket-name",
                "arn:aws:s3:::cert-bucket-name/*"
            ]
        }
    ]
}
```

The `DNS_PROFILE` should assume a role with the following policy:

```javascript
{
    "Version": "2012-10-17",
    "Id": "certbot-dns-route53 sample policy",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "route53:ListHostedZones",
                "route53:GetChange"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Effect" : "Allow",
            "Action" : [
                "route53:ChangeResourceRecordSets"
            ],
            "Resource" : [
                "arn:aws:route53:::hostedzone/YOURHOSTEDZONEID"
            ]
        }
    ]
}
```

### Certificate Access Role ###

To access a specific certificate, a role with the following profile should be
assumed:

```javascript
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "allow-cert-read",
            "Effect": "Allow",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::cert-bucket-name/live/lemmy.imotorhead.com/*"
        }
    ]
}
```

### Accessing and Installing Certificates at Instance Boot Time ###

The certificates created by Certboto can be installed on a booting instance
using [cloud-init](https://cloudinit.readthedocs.io/en/latest/).  An implementation
of this can be found in the
[openvpn-server-tf-module](https://github.com/cisagov/openvpn-server-tf-module)
project.  Specifically
[`install-certificates.py`](https://github.com/cisagov/openvpn-server-tf-module/blob/develop/cloudinit/install-certificates.py)

## Contributing ##

We welcome contributions!  Please see [`CONTRIBUTING.md`](CONTRIBUTING.md) for
details.

## License ##

This project is in the worldwide [public domain](LICENSE).

This project is in the public domain within the United States, and
copyright and related rights in the work worldwide are waived through
the [CC0 1.0 Universal public domain
dedication](https://creativecommons.org/publicdomain/zero/1.0/).

All contributions to this project will be released under the CC0
dedication. By submitting a pull request, you are agreeing to comply
with this waiver of copyright interest.
