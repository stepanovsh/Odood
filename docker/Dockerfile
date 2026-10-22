FROM python:3.12-slim-bookworm@sha256:6a0e06f5ba0b373d051aabd3fffb9b873f27f9a2a3a14bcbe37dee6f0e3bbc70 AS base

ARG ODOO_VERSION
ARG ODOOD_DEPENDENCIES
ARG TARGETARCH

# UID/GID 999 is the top of the system range (Postgres/MySQL/Redis use it too)
# and is free on the base image, so the 'odoo' system user gets a fixed,
# predictable ID.
ARG ODOOD_SERVER_USER_UID=999
ARG ODOOD_SERVER_USER_GID=999

RUN apt-get update -qq && \
    apt-get install -qqq -y --no-install-recommends --auto-remove \
        locales \
        wget \
        ca-certificates \
        xfonts-75dpi xfonts-base libx11-6 libxcb1 libxext6 libxrender1 libsqlite3-dev\
        tzdata && \
    sed -i \
        -e 's/^# *en_US\.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/' \
        -e 's/^# *en_GB\.UTF-8 UTF-8$/en_GB.UTF-8 UTF-8/' \
        /etc/locale.gen && \
    locale-gen && \
    update-locale LANG="en_US.UTF-8" && update-locale LANGUAGE="en_US:en" && \
    install -d -m 0755 /etc/apt/keyrings && \
    wget --quiet -O /etc/apt/keyrings/pgdg.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc && \
    echo "deb [signed-by=/etc/apt/keyrings/pgdg.asc] https://apt.postgresql.org/pub/repos/apt/ bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    apt-get update -qq && \
    apt-get install -qqq -y --no-install-recommends --auto-remove \
        $(printf '%s\n' "$ODOOD_DEPENDENCIES" | tr ' ' '\n' | grep -Ev '^(python3(-|$)|postgresql-client$)') \
        postgresql-client-18 && \
    python3 -m pip install --no-cache-dir \
        --cert /etc/ssl/certs/ca-certificates.crt \
        "pip==26.2.2" && \
    python3 -m pip install --no-cache-dir "virtualenv>=20.26.6" && \
    python3 -c 'import pip._vendor.certifi as c; assert "emSign ECC Root CA - G3" not in open(c.where()).read()' && \
    pg_dump --version | grep -qE '^pg_dump \(PostgreSQL\) 18\.' && \
    wget --quiet -O /tmp/wkhtmltopdf.deb https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.bookworm_$(dpkg --print-architecture).deb && \
        apt-get install -qqq -y --no-install-recommends /tmp/wkhtmltopdf.deb && \
        wkhtmltopdf --version | grep -q "with patched qt" && \
        printf '%s\n' '<html><body>PDF smoke test</body></html>' > /tmp/wkhtmltopdf-test.html && \
        wkhtmltopdf /tmp/wkhtmltopdf-test.html /tmp/wkhtmltopdf-test.pdf && \
        test -s /tmp/wkhtmltopdf-test.pdf && \
        rm -f /tmp/wkhtmltopdf-test.html /tmp/wkhtmltopdf-test.pdf && \
        rm -f /tmp/wkhtmltopdf.deb && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /root/.cache/pip/*

# Set corect locale-related environment variables
ENV LANG="en_US.UTF-8" LANGUAGE="en_US:en" LC_ALL="en_US.UTF-8"

COPY ./bin/${TARGETARCH}/odood /usr/bin/odood
COPY ./bin/${TARGETARCH}/odood.bash /etc/bash_completion.d/odood.bash
# Remove the deploy-generated master password in the same layer that created it.

RUN /usr/bin/odood deploy -v "$ODOO_VERSION" --supervisor=odood --log-to-stderr --db-password=odoo \
        --server-user-uid="$ODOOD_SERVER_USER_UID" --server-user-gid="$ODOOD_SERVER_USER_GID" && \
    /opt/odoo/venv/bin/python -c 'import PIL; assert PIL.__version__ == "13.0.0"' && \
    /opt/odoo/venv/bin/python -c 'import pip._vendor.certifi as c; assert "emSign ECC Root CA - G3" not in open(c.where()).read()' && \
    sed -i '/^[[:space:]]*admin_passwd[[:space:]]*=/d' /opt/odoo/conf/odoo.conf && \
    ! grep -q 'admin_passwd' /opt/odoo/conf/odoo.conf && \
    rm -rf /root/.cache/pip/*

WORKDIR /opt/odoo

EXPOSE 8069
EXPOSE 8071
EXPOSE 8072

VOLUME ["/opt/odoo/data", "/opt/odoo/backups"]

STOPSIGNAL SIGINT

CMD ["/usr/bin/odood", "--config-from-env", "server", "run", "--wait-pg"]


# Production image (default target): adds a HEALTHCHECK for orchestrators.
FROM base AS production

COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/odood-entrypoint

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD odood server healthcheck -t 9

ENTRYPOINT ["/usr/local/bin/odood-entrypoint"]


# CI image: no HEALTHCHECK (disposable test runner), with the dev/lint/test
# toolbelt (pre-commit, eslint, flake8, pylint-odoo, coverage, ...) pre-installed.
FROM base AS ci

RUN /usr/bin/odood venv install-dev-tools && \
    rm -rf /root/.cache

# Headless browser for Odoo tour / HttpCase (browser_js) tests: Odoo probes PATH
# for google-chrome/chromium and raises SkipTest when none is found. Google
# publishes google-chrome-stable for both amd64 and arm64. Kept out of the
# production image, which has no use for a browser.
RUN wget --quiet -O /tmp/google-chrome.deb \
        https://dl.google.com/linux/direct/google-chrome-stable_current_$(dpkg --print-architecture).deb && \
    apt-get update -qq && \
    apt-get install -qqq -y --no-install-recommends /tmp/google-chrome.deb && \
    google-chrome --version && \
    rm -f /tmp/google-chrome.deb && \
    rm -rf /var/lib/apt/lists/*
