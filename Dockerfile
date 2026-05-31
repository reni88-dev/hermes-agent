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

# --- Text editors ---
RUN apt-get update && apt-get install -y --no-install-recommends vim nano \
    && rm -rf /var/lib/apt/lists/*

# --- Persistent data ---
VOLUME ["/opt/data"]
WORKDIR /opt/data

# --- Entrypoint ---
# Logika: jika config.yaml ada (setup sudah dijalankan) → start gateway.
# Jika belum → container idle, tunggu 'hermes setup' via terminal.
# Setelah setup selesai, restart container → gateway otomatis jalan.
COPY entrypoint.sh /opt/hermes/entrypoint.sh
RUN chmod +x /opt/hermes/entrypoint.sh

ENTRYPOINT []
CMD ["/opt/hermes/entrypoint.sh"]
