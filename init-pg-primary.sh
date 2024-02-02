#!/bin/bash
set -e

# PostgreSQL environment variables
export PGUSER="$POSTGRES_USER"
export PGPASSWORD="$POSTGRES_PASSWORD"

# Wait for PostgreSQL to start
until psql -c '\q'; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 1
done

# Create a simple table
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE TABLE my_table (
        id SERIAL PRIMARY KEY,
        data VARCHAR(255)
    );
EOSQL

# Create a publication for the table
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE PUBLICATION my_publication FOR TABLE my_table;
EOSQL
