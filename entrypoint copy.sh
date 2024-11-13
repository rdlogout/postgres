#!/bin/bash

# Fix permissions on the data directory
echo "Fixing permissions on /var/lib/postgresql/data..."
chown -R postgres:postgres "$PGDATA"
# Configure pg_hba.conf to allow connections
echo "Configuring pg_hba.conf..."
cat > "$PGDATA/pg_hba.conf" << EOF
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             all                                     trust
host    all             all             127.0.0.1/32           trust
host    all             all             ::1/128                 trust
host    all             all             0.0.0.0/0              md5
hostssl all             all             0.0.0.0/0              md5
EOF

chmod 600 "$PGDATA/pg_hba.conf"

# Initialize database if not already initialized
if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo "Initializing database in $PGDATA..."
  initdb -D "$PGDATA"
fi

# Ensure SSL is enabled in postgresql.conf
if ! grep -q "ssl = on" "$PGDATA/postgresql.conf"; then
  echo "Enabling SSL settings in postgresql.conf..."
  echo "ssl = on" >> "$PGDATA/postgresql.conf"
  echo "ssl_cert_file = '/etc/ssl/postgresql/server.crt'" >> "$PGDATA/postgresql.conf"
  echo "ssl_key_file = '/etc/ssl/postgresql/server.key'" >> "$PGDATA/postgresql.conf"
fi

# Ensure correct file permissions for SSL certificates
chmod 600 /etc/ssl/postgresql/server.key
chown postgres:postgres /etc/ssl/postgresql/server.crt /etc/ssl/postgresql/server.key
echo "SSL certificates have been configured."
# Execute the default PostgreSQL entrypoint
exec postgres
