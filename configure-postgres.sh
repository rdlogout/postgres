#!/bin/bash

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

# Ensure SSL is enabled in postgresql.conf
echo "Enabling SSL settings in postgresql.conf..."
echo "ssl = on" >> "$PGDATA/postgresql.conf"
echo "ssl_cert_file = '/etc/ssl/postgresql/server.crt'" >> "$PGDATA/postgresql.conf"
echo "ssl_key_file = '/etc/ssl/postgresql/server.key'" >> "$PGDATA/postgresql.conf"

# Ensure correct file permissions
chmod 600 "$PGDATA/pg_hba.conf"
chmod 600 /etc/ssl/postgresql/server.key
chown postgres:postgres /etc/ssl/postgresql/server.crt /etc/ssl/postgresql/server.key