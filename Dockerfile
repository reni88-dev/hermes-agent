# =============================================================================
# Hermes Agent — Easypanel Deployment (ARM64)
# =============================================================================
# Menggunakan official multi-arch image (amd64 + arm64) dari NousResearch.
#
# Alur deploy di Easypanel:
#   1. Deploy Dockerfile ini → container hidup & idle
#   2. Buka terminal container di Easypanel
#   3. Jalankan: hermes setup
#   4. Setelah setup selesai, jalankan: hermes gateway run
#      (atau restart container dengan CMD yang diubah)
# =============================================================================

FROM nousresearch/hermes-agent:latest

# --- Timezone ---
ENV TZ=Asia/Jakarta

# --- Runtime environment ---
ENV HERMES_HOME=/opt/data
ENV PYTHONUNBUFFERED=1

# Pastikan hermes binary dapat diakses dari PATH
ENV PATH="/opt/hermes/bin:/opt/hermes/.venv/bin:${PATH}"

# --- Persistent data ---
VOLUME ["/opt/data"]
WORKDIR /opt/hermes

# --- Bypass s6-overlay ---
# Easypanel mengelola lifecycle container sendiri, tidak perlu s6-overlay.
# Container tetap hidup (idle) sampai user menjalankan 'hermes setup'
# via terminal Easypanel.
ENTRYPOINT []
CMD ["tail", "-f", "/dev/null"]
