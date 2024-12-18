#!/bin/sh

set -eu

# this will come from somewhere else later
connection="postgresql://postgres:password@localhost:5432"

db_name="${1:-""}"

if [ -z "${db_name}" ]; then
  echo "You must specify a database name as the first argument" >&2
  exit 1
fi

echo "==> Creating database"
echo "    Database: ${db_name}"

if psql "${connection}" --list --no-align --tuples-only | cut -d"|" -f1 | grep --quiet "^${db_name}\$"; then
  echo "--> Database exists, exiting"
  exit 0
fi

echo "create database :db_name;" | psql "${connection}" -v db_name="${db_name}"
