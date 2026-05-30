# ============================================================================
# Hermes Agent v0.15.2 — Dockerfile
# Built for deployment on EasyPanel (multi-arch: amd64/arm64)
#
# Arsitektur: Single-stage Debian 13.4 (trixie) + s6-overlay supervision
# Upstream:   https://github.com/NousResearch/hermes-agent
# ============================================================================

# ---------- Source stages (cached layers) ----------
FROM ghcr.io/astral-sh/uv:0.11.6-python3.13-trixie AS uv_source

# Node 22 LTS — Debian trixie ships nodejs 20.x (EOL April 2026).
# We copy node + npm + corepack from the upstream node:22 image instead
# so we stay on a supported LTS. Bookworm-slim ensures glibc compat.
FROM node:22-bookworm-slim AS node_source

# ---------- Main image ----------
FROM debian:13.4

# Disable Python stdout buffering for immediate log output
ENV PYTHONUNBUFFERED=1

# Store Playwright browsers outside the data volume mount so the
# build-time install survives the /opt/data volume overlay at runtime.
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/hermes/.playwright

# ---------------------------------------------------
# 1. System dependencies (single layer, APT cache cleared)
# ---------------------------------------------------
# s6-overlay replaces tini as PID 1 — it reaps zombie processes
# non-blockingly on SIGCHLD and supervises the main hermes process,
# the dashboard, and per-profile gateways.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    iputils-ping \
    python3 \
    python-is-python3 \
    ripgrep \
    ffmpeg \
    gcc \
    python3-dev \
    libffi-dev \
    procps \
    git \
    openssh-client \
    docker-cli \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------
# 2. s6-overlay install (PID 1 supervisor)
# ---------------------------------------------------
# Multi-arch: BuildKit auto-populates TARGETARCH (amd64/arm64).
# s6-overlay uses tarball names keyed on kernel arch string
# (x86_64/aarch64), so we map between them inline.
#
# Supply-chain integrity: every tarball is SHA256-verified against
# upstream-published checksums. A compromised artifact fails the
# build loudly instead of silently producing a tampered image.
ARG TARGETARCH
ARG S6_OVERLAY_VERSION=3.2.3.0
ARG S6_OVERLAY_NOARCH_SHA256=b720f9d9340efc8bb07528b9743813c836e4b02f8693d90241f047998b4c53cf
ARG S6_OVERLAY_X86_64_SHA256=a93f02882c6ed46b21e7adb5c0add86154f01236c93cd82c7d682722e8840563
ARG S6_OVERLAY_AARCH64_SHA256=0952056ff913482163cc30e35b2e944b507ba1025d78f5becbb89367bf344581
ARG S6_OVERLAY_SYMLINKS_SHA256=a60dc5235de3ecbcf874b9c1f18d73263ab99b289b9329aa950e8729c4789f0e

ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp/
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz /tmp/

RUN set -eu; \
    case "${TARGETARCH:-amd64}" in \
        amd64) s6_arch="x86_64"; s6_arch_sha="${S6_OVERLAY_X86_64_SHA256}" ;; \
        arm64) s6_arch="aarch64"; s6_arch_sha="${S6_OVERLAY_AARCH64_SHA256}" ;; \
        *) echo "Unsupported TARGETARCH=${TARGETARCH} for s6-overlay" >&2; exit 1 ;; \
    esac; \
    curl -fsSL --retry 3 -o /tmp/s6-overlay-arch.tar.xz \
        "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${s6_arch}.tar.xz"; \
    { \
        printf '%s  %s\n' "${S6_OVERLAY_NOARCH_SHA256}" /tmp/s6-overlay-noarch.tar.xz; \
        printf '%s  %s\n' "${s6_arch_sha}" /tmp/s6-overlay-arch.tar.xz; \
        printf '%s  %s\n' "${S6_OVERLAY_SYMLINKS_SHA256}" /tmp/s6-overlay-symlinks-noarch.tar.xz; \
    } > /tmp/s6-overlay.sha256; \
    sha256sum -c /tmp/s6-overlay.sha256; \
    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz; \
    tar -C / -Jxpf /tmp/s6-overlay-arch.tar.xz; \
    tar -C / -Jxpf /tmp/s6-overlay-symlinks-noarch.tar.xz; \
    rm /tmp/s6-overlay-*.tar.xz /tmp/s6-overlay.sha256

# ---------------------------------------------------
# 3. Non-root runtime user
# ---------------------------------------------------
# UID can be overridden at runtime via HERMES_UID environment variable.
# s6-overlay cont-init.d scripts handle UID/GID remapping.
RUN useradd -u 10000 -m -d /opt/data hermes

# ---------------------------------------------------
# 4. uv (Python package manager) — copy from official image
# ---------------------------------------------------
COPY --chmod=0755 --from=uv_source /usr/local/bin/uv /usr/local/bin/uvx /usr/local/bin/

# ---------------------------------------------------
# 5. Node.js 22 LTS — copy from official image
# ---------------------------------------------------
# Copy the node binary plus bundled npm + corepack. Symlinks are
# recreated because they don't survive cross-image COPY.
COPY --chmod=0755 --from=node_source /usr/local/bin/node /usr/local/bin/
COPY --from=node_source /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/npm
COPY --from=node_source /usr/local/lib/node_modules/corepack /usr/local/lib/node_modules/corepack
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx && \
    ln -sf /usr/local/lib/node_modules/corepack/dist/corepack.js /usr/local/bin/corepack

# ---------------------------------------------------
# 6. Clone Hermes Agent & install dependencies
# ---------------------------------------------------
WORKDIR /opt/hermes

RUN git clone --depth 1 https://github.com/NousResearch/hermes-agent.git . \
    && git submodule update --init mini-swe-agent

# Layer-cached dependency install: copy manifests first so npm install
# + Playwright are cached unless lockfiles themselves change.
# Note: if package.json or lock files exist in the repo, npm install
# handles Node.js dependencies.
RUN if [ -f package.json ]; then \
        npm install --silent 2>/dev/null || true; \
    fi

# Install Playwright Chromium with system deps
RUN npx playwright install --with-deps chromium 2>/dev/null || true

# Python virtual environment & dependencies
RUN uv venv venv --python 3.13

ENV VIRTUAL_ENV=/opt/hermes/venv \
    PATH="/opt/hermes/venv/bin:$PATH"

# Install main package with all extras; fallback to base if extras fail
RUN uv pip install -e ".[all]" || uv pip install -e "."

# Install mini-swe-agent submodule
RUN if [ -f mini-swe-agent/pyproject.toml ]; then \
        uv pip install -e ./mini-swe-agent; \
    fi

# Install WhatsApp bridge dependencies
RUN if [ -f scripts/whatsapp-bridge/package.json ]; then \
        cd scripts/whatsapp-bridge && npm install --silent 2>/dev/null || true; \
    fi

# ---------------------------------------------------
# 7. Copy custom entrypoint (EasyPanel-compatible wrapper)
# ---------------------------------------------------
COPY entrypoint.sh /opt/hermes/docker/main-wrapper.sh
RUN chmod +x /opt/hermes/docker/main-wrapper.sh

# ---------------------------------------------------
# 8. Runtime configuration
# ---------------------------------------------------
ENV HERMES_HOME=/opt/data \
    PATH="/opt/hermes/venv/bin:/usr/local/bin:$PATH" \
    VIRTUAL_ENV=/opt/hermes/venv

# Expose port:
# 8642 = API Server + Dashboard + Webhook (consolidated)
EXPOSE 8642

# s6-overlay /init as PID 1 — runs cont-init.d scripts (chown,
# profile reconcile, dashboard toggle) and sets up supervision tree
# before any service starts. main-wrapper.sh handles command routing.
ENTRYPOINT ["/init", "/opt/hermes/docker/main-wrapper.sh"]
CMD ["gateway"]
