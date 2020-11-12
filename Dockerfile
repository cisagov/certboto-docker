ARG VERSION=unspecified

FROM certbot/dns-route53

ARG VERSION

# For a list of pre-defined annotation keys and value types see:
# https://github.com/opencontainers/image-spec/blob/master/annotations.md
# Note: Additional labels are added by the build workflow.
LABEL org.opencontainers.image.authors="mark.feldhousen@cisa.dhs.gov"
LABEL org.opencontainers.image.vendor="Cyber and Infrastructure Security Agency"

RUN apk add python3
RUN pip3 install --upgrade pip && pip3 install --upgrade awscli boto3 docopt
COPY src/rebuild-symlinks.py src/entrypoint.sh src/version.txt /opt/certbot/
COPY src/config /root/.aws/config
RUN ln -snf /run/secrets/credentials /root/.aws/credentials

ENTRYPOINT ["./entrypoint.sh"]
CMD ["renew"]
