#!/bin/bash
set -Eeuo pipefail

# The inner sed finds the line number of the last match for the the regex ^\s*shared_preload_libraries\s*=
# The outer sed, operating on that line alone, extracts the text between single quotes after the equals sign
PREVIOUS_PRELOAD_LIBRARIES=$(sed -nE "$(sed -n '/^\s*shared_preload_libraries\s*=/ =' ${PGDATA}/postgresql.conf | tail -n 1) s/^\s*shared_preload_libraries\s*=\s*'(.*?)'/\1/p" ${PGDATA}/postgresql.conf)

# Add pglogical for logical replication support
NEW_PRELOAD_LIBRARIES="pg_cron,pg_stat_statements,pg_stat_kcache,pg_wait_sampling,pgaudit,timescaledb,pglogical"

cat >> ${PGDATA}/postgresql.conf << EOT
listen_addresses = '*'

shared_preload_libraries = '$(echo "$PREVIOUS_PRELOAD_LIBRARIES,$NEW_PRELOAD_LIBRARIES" | sed 's/^,//')'

# pg_cron
cron.database_name = '${PG_CRON_DB:-${POSTGRES_DB:-${POSTGRES_USER:-postgres}}}'

# MobilityDB recomendation
max_locks_per_transaction = 128
timescaledb.telemetry_level = off

# Enhanced Replication Settings
wal_level = 'logical'         # Enables logical replication
max_worker_processes = 20     # Increased for better replication performance
max_replication_slots = 10    # Slots for replication connections
max_wal_senders = 10         # Number of simultaneous replication connections
wal_keep_size = '1GB'        # Amount of WAL to retain
hot_standby = on             # Allows read-only queries on standby
hot_standby_feedback = on    # Prevents query conflicts on standby
track_commit_timestamp = on  # Required for logical replication
synchronous_commit = on      # Ensures reliable replication (can be 'off' for better performance)

# Connection Settings
max_connections = 100        # Adjust based on your needs
superuser_reserved_connections = 3

# SSL Configuration
ssl = on
ssl_cert_file = '/etc/postgresql/ssl/server.crt'
ssl_key_file = '/etc/postgresql/ssl/server.key'
ssl_prefer_server_ciphers = on
ssl_min_protocol_version = 'TLSv1.2'
EOT

# Update pg_hba.conf to allow replication connections
cat >> ${PGDATA}/pg_hba.conf << EOT

# Allow SSL connections
hostssl all             all             0.0.0.0/0               scram-sha-256

# Allow replication connections
hostssl replication     all             0.0.0.0/0               scram-sha-256
EOT