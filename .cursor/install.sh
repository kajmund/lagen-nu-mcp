#!/usr/bin/env bash
# Idempotent bootstrap for the lagen-nu-mcp dev environment.
# Safe to re-run: installs system + Python deps, provisions a local Postgres
# dev database, and applies the schema.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

PG_VERSION=16
DEV_DB=lagen_nu_dev
DEV_ROLE=lagen_dev
DEV_PASSWORD=lagen_dev
DEV_DATABASE_URL="postgresql://${DEV_ROLE}:${DEV_PASSWORD}@127.0.0.1:5432/${DEV_DB}"

echo "==> Installing system packages (python venv + postgresql)"
sudo apt-get update -qq
sudo apt-get install -y -qq \
  "python3.12-venv" \
  postgresql postgresql-contrib

echo "==> Creating Python virtualenv and installing package"
python3 -m venv .venv
# shellcheck disable=SC1091
. .venv/bin/activate
python -m pip install --quiet --upgrade pip
pip install --quiet -e '.[dev]'

echo "==> Starting local Postgres cluster"
if ! sudo pg_lsclusters -h | awk '{print $1"/"$2}' | grep -qx "${PG_VERSION}/main"; then
  sudo pg_createcluster "${PG_VERSION}" main
fi
sudo pg_ctlcluster "${PG_VERSION}" main start || true

echo "==> Provisioning dev role and database"
sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DEV_ROLE}'" \
  | grep -q 1 \
  || sudo -u postgres psql -c "CREATE ROLE ${DEV_ROLE} LOGIN PASSWORD '${DEV_PASSWORD}';"
sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DEV_DB}'" \
  | grep -q 1 \
  || sudo -u postgres psql -c "CREATE DATABASE ${DEV_DB} OWNER ${DEV_ROLE};"

echo "==> Applying schema (sql/001_schema.sql)"
PGPASSWORD="${DEV_PASSWORD}" psql -h 127.0.0.1 -U "${DEV_ROLE}" -d "${DEV_DB}" \
  -v ON_ERROR_STOP=1 -f sql/001_schema.sql

echo "==> Writing local .env (if absent)"
if [ ! -f .env ]; then
  cp .env.example .env
fi

echo "==> Exporting local DATABASE_URL into ~/.bashrc (idempotent)"
marker="# lagen-nu-mcp local dev database"
if ! grep -qF "${marker}" "${HOME}/.bashrc" 2>/dev/null; then
  {
    echo ""
    echo "${marker}"
    echo "export DATABASE_URL=\"${DEV_DATABASE_URL}\""
    echo "[ -f ${repo_root}/.venv/bin/activate ] && . ${repo_root}/.venv/bin/activate"
  } >> "${HOME}/.bashrc"
fi

echo "==> install.sh complete"
