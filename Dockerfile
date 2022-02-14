ARG VERSION=unspecified

FROM certbot/dns-route53:v1.23.0

ARG VERSION

# For a list of pre-defined annotation keys and value types see:
# https://github.com/opencontainers/image-spec/blob/master/annotations.md
# Note: Additional labels are added by the build workflow.
LABEL org.opencontainers.image.authors="mark.feldhousen@cisa.dhs.gov"
LABEL org.opencontainers.image.vendor="Cybersecurity and Infrastructure Security Agency"

RUN apk add --no-cache python3=3.8.10-r0
RUN pip3 install --no-cache-dir \
  pip==21.3.1 \
  setuptools==60.5.0 \
  wheel==0.37.1
RUN pip3 install --no-cache-dir \
  awscli==1.22.39 \
  boto3==1.20.39 \
  docopt==0.6.2
COPY src/rebuild-symlinks.py src/entrypoint.sh src/version.txt /opt/certbot/
COPY src/config /root/.aws/config
RUN ln -snf /run/secrets/credentials /root/.aws/credentials

ENTRYPOINT ["./entrypoint.sh"]
CMD ["renew"]
