# ============================================================================
# Hermes Agent — Dockerfile (ARM64 Compatible)
# Built for deployment on EasyPanel with ARM64 servers
# ============================================================================

FROM python:3.11-slim-bookworm AS builder

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1

# ---------------------------------------------------
# 1. System dependencies
# ---------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    build-essential \
    python3-dev \
    libffi-dev \
    ffmpeg \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install ripgrep (available in bookworm repos for arm64)
RUN apt-get update && apt-get install -y --no-install-recommends ripgrep \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------
# 2. Node.js 22 (for browser tools & Playwright)
# ---------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------
# 3. Install uv (Python package manager)
# ---------------------------------------------------
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# ---------------------------------------------------
# 4. Clone Hermes Agent repository
# ---------------------------------------------------
WORKDIR /opt
RUN git clone --depth 1 https://github.com/NousResearch/hermes-agent.git \
    && cd hermes-agent \
    && git submodule update --init mini-swe-agent

WORKDIR /opt/hermes-agent

# ---------------------------------------------------
# 5. Create virtualenv & install Python dependencies
# ---------------------------------------------------
RUN uv venv venv --python 3.11

ENV VIRTUAL_ENV=/opt/hermes-agent/venv \
    PATH="/opt/hermes-agent/venv/bin:$PATH"

# Install main package with all extras; fallback to base if extras fail
RUN uv pip install -e ".[all]" || uv pip install -e "."

# Install mini-swe-agent submodule
RUN if [ -f mini-swe-agent/pyproject.toml ]; then \
        uv pip install -e ./mini-swe-agent; \
    fi

# ---------------------------------------------------
# 6. Node.js dependencies (browser tools)
# ---------------------------------------------------
RUN if [ -f package.json ]; then npm install --silent 2>/dev/null || true; fi

# Install Playwright Chromium with system deps
RUN npx playwright install --with-deps chromium 2>/dev/null || true

# Install WhatsApp bridge dependencies
RUN if [ -f scripts/whatsapp-bridge/package.json ]; then \
        cd scripts/whatsapp-bridge && npm install --silent 2>/dev/null || true; \
    fi

# ============================================================================
# Runtime stage
# ============================================================================
FROM python:3.11-slim-bookworm AS runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HERMES_HOME=/root/.hermes \
    PATH="/opt/hermes-agent/venv/bin:/root/.local/bin:$PATH" \
    VIRTUAL_ENV=/opt/hermes-agent/venv

# Runtime system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    ffmpeg \
    ripgrep \
    vim \
    docker.io \
    # Playwright Chromium runtime deps
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libgbm1 \
    libpango-1.0-0 \
    libcairo2 \
    libasound2 \
    libxshmfence1 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libxfixes3 \
    fonts-liberation \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22 (runtime)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install uv (needed for hermes update)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Copy application from builder
COPY --from=builder /opt/hermes-agent /opt/hermes-agent

# Copy Playwright browsers from builder
COPY --from=builder /root/.cache/ms-playwright /root/.cache/ms-playwright

WORKDIR /opt/hermes-agent

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose ports:
# 8642 = API Server
# 8644 = Webhook Server
EXPOSE 8642 8644

ENTRYPOINT ["/entrypoint.sh"]
CMD ["gateway"]
