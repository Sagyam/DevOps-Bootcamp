#!/usr/bin/env bash
# Restore a backup into a target database.
#
# Usage:
#   ./restore.sh --key postgres/2026/08/tiffin-20260817T181500Z.dump \
#                --target tiffin_restore_test
#
# By default this refuses to touch the production database. Overriding that
# requires --i-understand, which is deliberately annoying to type.
set -euo pipefail

KEY=""
TARGET="tiffin_restore_test"
CONFIRM="no"

while [ $# -gt 0 ]; do
  case "$1" in
    --key) KEY="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --i-understand) CONFIRM="yes"; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

: "${KEY:?--key is required}" "${S3_BUCKET:?}" "${PGHOST:?}" "${PGUSER:?}" "${PGPASSWORD:?}"

if [ "${TARGET}" = "tiffin" ] && [ "${CONFIRM}" != "yes" ]; then
  echo "Refusing to restore over the live database without --i-understand" >&2
  exit 1
fi

WORK=$(mktemp -d)
trap 'rm -rf "${WORK}"' EXIT

echo "==> downloading ${KEY}"
aws s3 cp "s3://${S3_BUCKET}/${KEY}" "${WORK}/dump" --only-show-errors
aws s3 cp "s3://${S3_BUCKET}/${KEY}.sha256" "${WORK}/dump.sha256" --only-show-errors

echo "==> verifying checksum"
EXPECTED=$(cat "${WORK}/dump.sha256")
ACTUAL=$(sha256sum "${WORK}/dump" | awk '{print $1}')
[ "${EXPECTED}" = "${ACTUAL}" ] || { echo "CHECKSUM MISMATCH" >&2; exit 1; }

echo "==> recreating target database ${TARGET}"
psql -d postgres -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS ${TARGET};"
psql -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE ${TARGET} OWNER ${PGUSER};"

echo "==> restoring"
START=$(date +%s)
pg_restore --dbname="${TARGET}" --no-owner --no-privileges --exit-on-error "${WORK}/dump"
END=$(date +%s)

echo "==> validating"
ORDERS=$(psql -d "${TARGET}" -tAc "SELECT count(*) FROM orders;")
ITEMS=$(psql -d "${TARGET}" -tAc "SELECT count(*) FROM menu_items;")
LATEST=$(psql -d "${TARGET}" -tAc "SELECT COALESCE(max(created_at)::text,'none') FROM orders;")

echo
echo "Restore complete in $((END-START))s"
echo "  orders:      ${ORDERS}"
echo "  menu_items:  ${ITEMS}"
echo "  latest order: ${LATEST}"
echo
echo "Record these numbers in the DR drill log along with the wall-clock"
echo "time from 'we noticed' to 'validated'. That number is your real RTO."
