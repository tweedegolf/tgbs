FROM ghcr.io/tweedegolf/debian:bookworm

# Install postgresql client
ENV POSTGRESQL_VERSION 16
RUN install -d /usr/share/postgresql-common/pgdg \
    && curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    && echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] http://apt.postgresql.org/pub/repos/apt/ bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        postgresql-client-$POSTGRESQL_VERSION \
        bzip2 \
        python3 \
    && rm -rf /var/lib/apt/lists/*

# https://github.com/restic/restic/releases
ENV RESTIC_VERSION 0.16.4
# install restic, see https://restic.readthedocs.io/en/stable/020_installation.html#official-binaries
RUN curl -sSLfo /usr/local/bin/restic.bz2 \
    "https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/restic_${RESTIC_VERSION}_linux_amd64.bz2"  \
    && bzip2 -d /usr/local/bin/restic.bz2 \
    && chmod +x /usr/local/bin/restic

# Install backup scripts
COPY bin/* /usr/local/bin/
CMD ["/usr/local/bin/backup.sh"]
