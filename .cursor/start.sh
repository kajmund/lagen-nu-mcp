#!/usr/bin/env bash
# Per-boot startup: ensure the local Postgres cluster is running.
# Dependency installation lives in install.sh, not here.
set -euo pipefail

PG_VERSION=16

if sudo pg_lsclusters -h | awk '{print $1"/"$2}' | grep -qx "${PG_VERSION}/main"; then
  sudo pg_ctlcluster "${PG_VERSION}" main start || true
  echo "postgres ${PG_VERSION}/main started (or already running)"
else
  echo "postgres cluster ${PG_VERSION}/main not found; run .cursor/install.sh" >&2
fi
