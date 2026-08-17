#!/usr/bin/env bash
# Nightly logical backup. Runs in the CronJob; also runnable by hand.
#
# Design notes for readers:
#   - set -euo pipefail so a failure is a failure, not a zero-byte upload
#   - the backup is verified before it is uploaded, not after
#   - a checksum is stored beside it so restore can prove integrity
set -euo pipefail

: "${PGHOST:?}" "${PGUSER:?}" "${PGDATABASE:?}" "${PGPASSWORD:?}" "${S3_BUCKET:?}"

WORKDIR="${WORKDIR:-/work}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DUMP="${WORKDIR}/tiffin-${STAMP}.dump"
KEY="postgres/${STAMP:0:4}/${STAMP:4:2}/tiffin-${STAMP}.dump"

log() { printf '{"ts":"%s","level":"info","msg":"%s"}\n' "$(date -u +%FT%TZ)" "$1"; }
fail() { printf '{"ts":"%s","level":"error","msg":"%s"}\n' "$(date -u +%FT%TZ)" "$1" >&2; exit 1; }

log "starting dump of ${PGDATABASE} from ${PGHOST}"
# Custom format (-Fc) is compressed and allows selective restore.
pg_dump --format=custom --compress=6 --no-owner --no-privileges \
        --file="${DUMP}" || fail "pg_dump failed"

SIZE=$(stat -c%s "${DUMP}")
[ "${SIZE}" -gt 1024 ] || fail "dump is suspiciously small (${SIZE} bytes)"
log "dump complete, ${SIZE} bytes"

# Verify the archive is readable before trusting it. This catches truncation
# and corruption at backup time rather than at restore time.
pg_restore --list "${DUMP}" > /dev/null || fail "dump failed integrity check"
log "integrity check passed"

sha256sum "${DUMP}" | awk '{print $1}' > "${DUMP}.sha256"

aws s3 cp "${DUMP}" "s3://${S3_BUCKET}/${KEY}" \
  --sse aws:kms --only-show-errors || fail "upload failed"
aws s3 cp "${DUMP}.sha256" "s3://${S3_BUCKET}/${KEY}.sha256" \
  --sse aws:kms --only-show-errors || fail "checksum upload failed"

log "uploaded s3://${S3_BUCKET}/${KEY}"
rm -f "${DUMP}" "${DUMP}.sha256"

# Emit a metric so a missed backup pages someone. A silent backup failure is
# indistinguishable from success until the day you need it.
if [ -n "${PUSHGATEWAY_URL:-}" ]; then
  printf 'tiffin_backup_last_success_timestamp %s\n' "$(date +%s)" \
    | curl -sS --data-binary @- "${PUSHGATEWAY_URL}/metrics/job/tiffin_backup" || true
fi
