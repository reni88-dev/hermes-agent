#!/bin/bash
set -e

# ============================================================================
# Hermes Agent v0.15.2 — main-wrapper.sh (s6-overlay compatible)
#
# Script ini dijalankan oleh s6-overlay /init sebagai main service.
# s6-overlay sudah jadi PID 1, menangani:
#   - Zombie process reaping (SIGCHLD)
#   - cont-init.d scripts (UID/GID remapping, volume ownership, seeding)
#   - Service supervision (auto-restart on crash)
#
# ENTRYPOINT di Dockerfile: ["/init", "/opt/hermes/docker/main-wrapper.sh"]
# ============================================================================

HERMES_HOME="${HERMES_HOME:-/opt/data}"

# ============================================================================
# Initialize directory structure if not exists
# ============================================================================
echo "☤ Hermes Agent v0.15.2 — Initializing..."

mkdir -p "$HERMES_HOME"/{cron,sessions,logs,pairing,hooks,image_cache,audio_cache,memories,skills,profiles,whatsapp/session}

# Create default SOUL.md if not exists
if [ ! -f "$HERMES_HOME/SOUL.md" ]; then
    cat > "$HERMES_HOME/SOUL.md" << 'EOF'
# Hermes Agent Persona
<!--
This file defines the agent's personality and tone.
Edit this to customize how Hermes communicates with you.

Examples:
  - "You are a warm, playful assistant who uses kaomoji occasionally."
  - "You are a concise technical expert. No fluff, just facts."
  - "You speak like a friendly coworker who happens to know everything."

This file is loaded fresh each message -- no restart needed.
Delete the contents (or this file) to use the default personality.
-->
EOF
    echo "  ✓ Created default SOUL.md"
fi

# Create .env from environment if not exists
if [ ! -f "$HERMES_HOME/.env" ]; then
    touch "$HERMES_HOME/.env"
    echo "  ✓ Created empty .env (run 'hermes setup' to configure)"
fi

# Create default config.yaml if not exists
if [ ! -f "$HERMES_HOME/config.yaml" ]; then
    if [ -f /opt/hermes/cli-config.yaml.example ]; then
        cp /opt/hermes/cli-config.yaml.example "$HERMES_HOME/config.yaml"
        echo "  ✓ Created config.yaml from template"
    fi
fi

# Sync bundled skills
echo "  → Syncing bundled skills..."
python /opt/hermes/tools/skills_sync.py 2>/dev/null || {
    if [ -d /opt/hermes/skills ]; then
        cp -r /opt/hermes/skills/* "$HERMES_HOME/skills/" 2>/dev/null || true
    fi
}
echo "  ✓ Skills synced"

# Fix ownership if running as root with HERMES_UID set
if [ "$(id -u)" = "0" ] && [ -n "${HERMES_UID:-}" ]; then
    echo "  → Fixing ownership for UID=${HERMES_UID}..."
    usermod -u "${HERMES_UID}" hermes 2>/dev/null || true
    if [ -n "${HERMES_GID:-}" ]; then
        groupmod -g "${HERMES_GID}" hermes 2>/dev/null || true
    fi
    chown -R hermes:hermes "$HERMES_HOME" 2>/dev/null || true
    echo "  ✓ Ownership updated"
fi

echo "☤ Hermes Agent v0.15.2 — Ready!"
echo ""

# ============================================================================
# Run mode selection
# ============================================================================
case "${1:-gateway}" in
    gateway)
        echo "Starting Hermes messaging gateway..."
        echo "  Port: 8642 (API + Dashboard + Webhook)"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Jika baru pertama kali, buka Terminal di"
        echo "  EasyPanel dan jalankan:  hermes setup"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        # Jika s6-overlay tersedia, gateway dikelola oleh s6-supervise
        # Jika tidak, fallback ke exec langsung
        if [ -x /command/s6-svc ]; then
            exec hermes gateway run
        else
            exec hermes gateway
        fi
        ;;
    setup)
        echo "Running Hermes setup wizard..."
        exec hermes setup
        ;;
    cli)
        echo "Starting Hermes CLI..."
        exec hermes
        ;;
    shell)
        echo "Starting shell..."
        exec /bin/bash
        ;;
    sleep)
        echo "Container running in sleep mode."
        echo "Gunakan Terminal EasyPanel untuk menjalankan:"
        echo "  hermes setup    → Setup wizard"
        echo "  hermes gateway  → Start messaging gateway"
        echo "  hermes          → Interactive CLI"
        echo ""
        echo "Fitur baru v0.15.2:"
        echo "  hermes kanban swarm   → Multi-agent swarm"
        echo "  hermes mcp catalog    → Browse MCP integrations"
        echo "  hermes profile list   → Manage profiles"
        exec sleep infinity
        ;;
    *)
        exec "$@"
        ;;
esac
