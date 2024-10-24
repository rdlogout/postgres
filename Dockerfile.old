# Use the official PostgreSQL 16 image as the base
FROM postgres:16

# Set environment variables for PostgreSQL user and password
ENV POSTGRES_USER=postgres

# Install essential packages and PostgreSQL extensions
RUN apt-get update && apt-get install -y \
    postgresql-16-postgis-3 \
    postgresql-16-cron \
    postgresql-16-pgvector \
    build-essential \
    git \
    postgresql-server-dev-16 \
    wget \
    ca-certificates \
    libcurl4-openssl-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Switch to root user to modify configuration files
USER root

# Add the required shared preload libraries
RUN echo "shared_preload_libraries = 'pg_cron,pg_net'" >> /usr/share/postgresql/postgresql.conf.sample

# Install pg_net extension as root
RUN git clone https://github.com/supabase/pg_net.git && \
    cd pg_net && \
    make && \
    make install && \
    cd .. && rm -rf pg_net

# Switch back to the default postgres user
USER postgres

# Set default timezone for cron jobs
ENV PGCRON_TZ=UTC
