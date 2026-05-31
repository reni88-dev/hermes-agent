#!/bin/sh
# =============================================================================
# entrypoint.sh — Hermes Agent Easypanel Entrypoint
# =============================================================================
# Logika:
#   - Jika config sudah ada (setup pernah dijalankan) → start gateway
#   - Jika belum ada config → idle, tunggu user jalankan 'hermes setup'
# =============================================================================

set -e

HERMES_HOME="${HERMES_HOME:-/opt/data}"
CONFIG_FILE="${HERMES_HOME}/config.yaml"
LOG_FILE="${HERMES_HOME}/gateway.log"

echo "[entrypoint] HERMES_HOME=${HERMES_HOME}"
echo "[entrypoint] Timezone: $(date +%Z) ($(date))"

if [ -f "$CONFIG_FILE" ]; then
    echo "[entrypoint] Config ditemukan. Menjalankan hermes gateway..."
    echo "[entrypoint] Log: ${LOG_FILE}"
    exec hermes gateway run 2>&1 | tee "$LOG_FILE"
else
    echo "[entrypoint] Config belum ada."
    echo "[entrypoint] Buka terminal Easypanel dan jalankan: hermes setup"
    echo "[entrypoint] Container idle — menunggu setup..."
    exec tail -f /dev/null
fi
