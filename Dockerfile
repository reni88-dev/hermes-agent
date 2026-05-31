# =============================================================================
# Hermes Agent — Easypanel / ARM64 Deployment
# =============================================================================
# Uses the official multi-arch image (amd64 + arm64) from NousResearch.
# No source build needed — the image ships with Python venv, Node.js,
# s6-overlay supervisor, Playwright browsers, and all dependencies.
#
# Build:
#   docker build -t hermes-agent .
#
# Run (interactive setup):
#   docker run -it --rm -v ./hermes-data:/opt/data hermes-agent setup
#
# Run (gateway mode):
#   docker run -d --name hermes --restart unless-stopped \
#     -v ./hermes-data:/opt/data \
#     -p 8642:8642 -p 9119:9119 \
#     --env-file .env \
#     hermes-agent gateway run
# =============================================================================

FROM nousresearch/hermes-agent:latest

# --- Labels (OCI / Easypanel metadata) ---
LABEL maintainer="your-email@example.com"
LABEL org.opencontainers.image.title="Hermes Agent"
LABEL org.opencontainers.image.description="Self-improving AI agent by NousResearch — Easypanel deployment"
LABEL org.opencontainers.image.source="https://github.com/NousResearch/hermes-agent"
LABEL org.opencontainers.image.licenses="MIT"

# --- Timezone ---
ENV TZ=Asia/Jakarta

# --- Health check ---
# Uses s6-svstat to verify the gateway process is alive.
# If API_SERVER_ENABLED=true, can also use: curl -sf http://localhost:8642/health
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD /command/s6-svstat /run/service/main-hermes 2>/dev/null | grep -q "true" || exit 1

# --- Expose ports (optional) ---
# Only needed if you enable the dashboard or API server.
# Telegram/Discord/Slack gateways run outbound — no inbound ports required.
# 8642 = Gateway API server (OpenAI-compatible) + health endpoint
# 9119 = Web dashboard
# EXPOSE 8642 9119

# --- Persistent data volume ---
VOLUME ["/opt/data"]
