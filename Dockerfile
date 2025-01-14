ARG BASE_IMAGE_TAG=latest

FROM postgis/postgis:$BASE_IMAGE_TAG AS base-image




FROM base-image AS basic-deps

RUN apt-get update && \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		curl




FROM basic-deps AS powa-scripts

WORKDIR /tmp/powa
RUN (curl --fail -LOJ "https://raw.githubusercontent.com/powa-team/powa-podman/master/powa-archivist/$PG_MAJOR/setup_powa-archivist.sh" || \
	curl --fail -LOJ "https://raw.githubusercontent.com/powa-team/powa-podman/master/powa-archivist-git/setup_powa-archivist.sh") && \
	(curl --fail -LOJ "https://raw.githubusercontent.com/powa-team/powa-podman/master/powa-archivist/$PG_MAJOR/install_all_powa_ext.sql" || \
	curl --fail -LOJ "https://raw.githubusercontent.com/powa-team/powa-podman/master/powa-archivist-git/install_all_powa_ext.sql")




FROM basic-deps AS common-deps

# /var/lib/apt/lists/ still has the indexes from parent stage, so there's no need to run apt-get update again.
# (unless the parent stage cache is not invalidated...)
RUN apt-get install -y --no-install-recommends \
	build-essential \
	cmake \
	postgresql-server-dev-$PG_MAJOR




FROM common-deps AS build-timescaledb

WORKDIR /tmp/timescaledb
RUN apt-get install -y --no-install-recommends libkrb5-dev && \
	URL_END=$(case "$PG_MAJOR" in ("12") echo "tag/2.11.2";; ("13") echo "tag/2.15.3";; (*) echo "latest";; esac) && \
	ASSET_NAME=$(basename $(curl -LIs -o /dev/null -w %{url_effective} https://github.com/timescale/timescaledb/releases/${URL_END})) && \
	curl --fail -L "https://github.com/timescale/timescaledb/archive/${ASSET_NAME}.tar.gz" | tar -zx --strip-components=1 -C . && \
	./bootstrap
WORKDIR /tmp/timescaledb/build
RUN make -j$(nproc) && \
	make install




FROM common-deps AS pgxn

RUN apt-get install -y --no-install-recommends pgxnclient && \
	pgxn install --verbose ddlx && \
	pgxn install --verbose json_accessors && \
	pgxn install --verbose parray_gin && \
	pgxn install --verbose permuteseq && \
	pgxn install --verbose pg_jobmon && \
	pgxn install --verbose pg_rowalesce && \
	pgxn install --verbose pg_uuidv7 && \
	pgxn install --verbose pg_xenophile && \
	pgxn install --verbose pg_xxhash && \
	pgxn install --verbose pgmq && \
	pgxn install --verbose pgsql_tweaks && \
	pgxn install --verbose temporal_tables




FROM common-deps AS build-pguint

WORKDIR /tmp/pguint
RUN ASSET_NAME=$(basename $(curl -LIs -o /dev/null -w %{url_effective} https://github.com/petere/pguint/releases/latest)) && \
	curl --fail -L "https://github.com/petere/pguint/archive/${ASSET_NAME}.tar.gz" | tar -zx --strip-components=1 -C . && \
	make && \
	make install




FROM common-deps AS build-sqlite_fdw

WORKDIR /tmp/sqlite_fdw
RUN apt-get install -y --no-install-recommends libsqlite3-dev && \
	ASSET_NAME=$(basename $(curl -LIs -o /dev/null -w %{url_effective} https://github.com/pgspider/sqlite_fdw/releases/latest)) && \
	curl --fail -L "https://github.com/pgspider/sqlite_fdw/archive/${ASSET_NAME}.tar.gz" | tar -zx --strip-components=1 -C . && \
	make USE_PGXS=1 && \
	make USE_PGXS=1 install




FROM basic-deps AS ssl-setup

RUN mkdir -p /etc/postgresql/ssl && \
    openssl req -new -x509 -days 365 -nodes \
    -out /etc/postgresql/ssl/server.crt \
    -keyout /etc/postgresql/ssl/server.key \
    -subj "/CN=localhost" && \
    chmod 600 /etc/postgresql/ssl/server.key




FROM base-image AS final-stage

RUN apt-get update && \
	apt-get install -y --no-install-recommends \
		libsqlite3-mod-spatialite \
		postgresql-$PG_MAJOR-credcheck \
		postgresql-$PG_MAJOR-cron \
		postgresql-$PG_MAJOR-hypopg \
		postgresql-$PG_MAJOR-partman \
		postgresql-$PG_MAJOR-pg-hint-plan \
		postgresql-$PG_MAJOR-pg-qualstats \
		postgresql-$PG_MAJOR-pg-stat-kcache \
		postgresql-$PG_MAJOR-pg-track-settings \
		postgresql-$PG_MAJOR-pg-wait-sampling \
		postgresql-$PG_MAJOR-pgaudit \
		postgresql-$PG_MAJOR-pgauditlogtofile \
		postgresql-$PG_MAJOR-pglogical \
		postgresql-$PG_MAJOR-pgtap \
		postgresql-$PG_MAJOR-pgvector \
		postgresql-$PG_MAJOR-pldebugger \
		postgresql-$PG_MAJOR-plpgsql-check \
		postgresql-$PG_MAJOR-powa \
		postgresql-$PG_MAJOR-repack \
		postgresql-$PG_MAJOR-set-user \
		postgresql-$PG_MAJOR-show-plans \
		postgresql-$PG_MAJOR-squeeze \
		postgresql-$PG_MAJOR-wal2json \
		postgresql-plperl-$PG_MAJOR \
		postgresql-plpython3-$PG_MAJOR && \
	if [ "$PG_MAJOR" -ge 14 ]; then \
		apt-get install -y --no-install-recommends postgresql-$PG_MAJOR-pgfaceting; \
	fi && \
	apt-get purge -y --auto-remove && \
	rm -rf /var/lib/apt/lists/*

COPY --from=powa-scripts \
	/tmp/powa/setup_powa-archivist.sh \
	/docker-entrypoint-initdb.d/setup_powa-archivist.sh
COPY --from=powa-scripts \
	/tmp/powa/install_all_powa_ext.sql \
	/usr/local/src/install_all_powa_ext.sql

COPY --from=pgxn \
	/usr/share/postgresql/$PG_MAJOR/extension/ \
	/usr/share/postgresql/$PG_MAJOR/extension/
COPY --from=pgxn \
	/usr/lib/postgresql/$PG_MAJOR/lib \
	/usr/lib/postgresql/$PG_MAJOR/lib

COPY --from=build-timescaledb \
	/usr/share/postgresql/$PG_MAJOR/extension/timescaledb* \
	/usr/share/postgresql/$PG_MAJOR/extension/
COPY --from=build-timescaledb \
	/usr/lib/postgresql/$PG_MAJOR/lib/timescaledb* \
	/usr/lib/postgresql/$PG_MAJOR/lib/

COPY --from=build-pguint \
	/usr/share/postgresql/$PG_MAJOR/extension/uint* \
	/usr/share/postgresql/$PG_MAJOR/extension/
COPY --from=build-pguint \
	/usr/lib/postgresql/$PG_MAJOR/lib/uint* \
	/usr/lib/postgresql/$PG_MAJOR/lib/

COPY --from=build-sqlite_fdw \
	/usr/share/postgresql/$PG_MAJOR/extension/sqlite_fdw* \
	/usr/share/postgresql/$PG_MAJOR/extension/
COPY --from=build-sqlite_fdw \
	/usr/lib/postgresql/$PG_MAJOR/lib/bitcode/sqlite_fdw.index.bc \
	/usr/lib/postgresql/$PG_MAJOR/lib/bitcode/sqlite_fdw.index.bc
COPY --from=build-sqlite_fdw \
	/usr/lib/postgresql/$PG_MAJOR/lib/bitcode/sqlite_fdw \
	/usr/lib/postgresql/$PG_MAJOR/lib/bitcode/sqlite_fdw
COPY --from=build-sqlite_fdw \
	/usr/lib/postgresql/$PG_MAJOR/lib/sqlite_fdw.so \
	/usr/lib/postgresql/$PG_MAJOR/lib/sqlite_fdw.so

COPY ./conf.sh  /docker-entrypoint-initdb.d/z_conf.sh

COPY --from=ssl-setup \
    /etc/postgresql/ssl \
    /etc/postgresql/ssl

RUN chown -R postgres:postgres /etc/postgresql/ssl && \
    chmod 600 /etc/postgresql/ssl/server.key && \
    chmod 644 /etc/postgresql/ssl/server.crt