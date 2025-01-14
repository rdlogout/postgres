#!/bin/bash

# Fix permissions on the data directory
echo "Fixing permissions on /var/lib/postgresql/data..."
chown -R postgres:postgres "$PGDATA"
chmod 700 "$PGDATA"

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
