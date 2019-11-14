ARG GIT_COMMIT=unspecified
ARG GIT_REMOTE=unspecified
ARG VERSION=unspecified

FROM certbot/dns-route53

ARG GIT_COMMIT
ARG GIT_REMOTE
ARG VERSION

LABEL git_commit=${GIT_COMMIT}
LABEL git_remote=${GIT_REMOTE}
LABEL maintainer="mark.feldhousen@trio.dhs.gov"
LABEL vendor="Cyber and Infrastructure Security Agency"
LABEL version=${VERSION}

RUN apk add python3
RUN pip3 install --upgrade pip && pip3 install --upgrade awscli boto3 docopt
COPY src/rebuild-symlinks.py src/entrypoint.sh src/version.txt /opt/certbot/
COPY src/config /root/.aws/config
RUN ln -snf /run/secrets/credentials /root/.aws/credentials

ENTRYPOINT ["./entrypoint.sh"]
CMD ["renew"]
