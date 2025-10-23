# Official Docker images are in the form library/<app> while non-official
# images are in the form <user>/<app>.
FROM docker.io/certbot/dns-route53:v1.32.0 AS compile-stage

# Location of the Python virtual environment
ENV CERTBOT_HOME="/opt/certbot"
ENV VIRTUAL_ENV="${CERTBOT_HOME}/.venv"

# Versions of the Python packages installed directly
ENV PYTHON_PIP_VERSION=21.3.1
ENV PYTHON_PIPENV_VERSION=2025.0.4
ENV PYTHON_SETUPTOOLS_VERSION=60.5.0
ENV PYTHON_WHEEL_VERSION=0.37.1

# Install Python 3
RUN apk --quiet add python3=3.10.14-r1

###
# Install the specified versions of pip, setuptools, and wheel into the system
# Python environment; install the specified version of pipenv into the system Python
# environment; set up a Python virtual environment (venv); and install the specified
# versions of pip, setuptools, and wheel into the venv.
#
# Note that we use the --no-cache-dir flag to avoid writing to a local
# cache.  This results in a smaller final image, at the cost of
# slightly longer install times.
###
RUN python3 -m pip install --no-cache-dir --upgrade \
        pip==${PYTHON_PIP_VERSION} \
        setuptools==${PYTHON_SETUPTOOLS_VERSION} \
        wheel==${PYTHON_WHEEL_VERSION} \
    && python3 -m pip install --no-cache-dir --upgrade \
        pipenv==${PYTHON_PIPENV_VERSION} \
    # Manually create the virtual environment
    && python3 -m venv ${VIRTUAL_ENV} \
    # Ensure the core Python packages are installed in the virtual environment
    && ${VIRTUAL_ENV}/bin/python3 -m pip install --no-cache-dir --upgrade \
        pip==${PYTHON_PIP_VERSION} \
        setuptools==${PYTHON_SETUPTOOLS_VERSION} \
        wheel==${PYTHON_WHEEL_VERSION}

###
# Install the Python dependencies into the virtual environment.
#
# Note that pipenv will install into a virtual environment if the VIRTUAL_ENV
# environment variable is set.
###
WORKDIR /tmp
COPY src/Pipfile src/Pipfile.lock ./
RUN pipenv install --clear --deploy --extra-pip-args "--no-cache-dir" --verbose

# Official Docker images are in the form library/<app> while non-official
# images are in the form <user>/<app>.
FROM docker.io/certbot/dns-route53:v1.32.0 AS build-stage

# Location of the Python virtual environment
ENV CERTBOT_HOME="/opt/certbot"
ENV VIRTUAL_ENV="${CERTBOT_HOME}/.venv"

###
# For a list of pre-defined annotation keys and value types see:
# https://github.com/opencontainers/image-spec/blob/master/annotations.md
#
# Note: Additional labels are added by the build workflow.
###
LABEL org.opencontainers.image.authors="vm-dev@gwe.cisa.dhs.gov"
LABEL org.opencontainers.image.vendor="Cybersecurity and Infrastructure Security Agency"

###
# This Docker container does not use an unprivileged user because it
# touches certbot's internal files and therefore must run as root.
###

###
# Install Python 3
#
# Note that we use apk --no-cache to avoid writing to a local cache.
# This results in a smaller final image, at the cost of slightly
# longer install times.
###
RUN apk --no-cache --quiet add "python3=3.10.14-r1"

# Copy in the Python virtual environment created in compile-stage, symlink the
# Python binary in the venv to the system-wide Python, and add the venv to the PATH.
#
# Note that we symlink the Python binary in the venv to the system-wide Python so that
# any calls to `python3` will use our virtual environment. We are using short flags
# because the ln binary in Alpine Linux does not support long flags. The -f instructs
# ln to remove the existing file and the -s instructs ln to create a symbolic link.
###
COPY --from=compile-stage ${VIRTUAL_ENV} ${VIRTUAL_ENV}
RUN ln -sf "$(command -v python3)" "${VIRTUAL_ENV}"/bin/python3
ENV PATH="${VIRTUAL_ENV}/bin:$PATH"

###
# Setup entrypoint
###
COPY src/rebuild-symlinks.py src/entrypoint.sh src/version.txt ${CERTBOT_HOME}
COPY src/config /root/.aws/config
RUN ln -snf /run/secrets/credentials /root/.aws/credentials

###
# Prepare to run
###
ENTRYPOINT ["./entrypoint.sh"]
CMD ["renew"]
