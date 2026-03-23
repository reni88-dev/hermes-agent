#!/bin/bash
set -e

HERMES_HOME="${HERMES_HOME:-/root/.hermes}"

# ============================================================================
# Initialize directory structure if not exists
# ============================================================================
echo "☤ Hermes Agent — Initializing..."

mkdir -p "$HERMES_HOME"/{cron,sessions,logs,pairing,hooks,image_cache,audio_cache,memories,skills,whatsapp/session}

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
    if [ -f /opt/hermes-agent/cli-config.yaml.example ]; then
        cp /opt/hermes-agent/cli-config.yaml.example "$HERMES_HOME/config.yaml"
        echo "  ✓ Created config.yaml from template"
    fi
fi

# Sync bundled skills
echo "  → Syncing bundled skills..."
python /opt/hermes-agent/tools/skills_sync.py 2>/dev/null || {
    if [ -d /opt/hermes-agent/skills ]; then
        cp -r /opt/hermes-agent/skills/* "$HERMES_HOME/skills/" 2>/dev/null || true
    fi
}
echo "  ✓ Skills synced"

echo "☤ Hermes Agent — Ready!"
echo ""

# ============================================================================
# Run mode selection
# ============================================================================
case "${1:-gateway}" in
    gateway)
        echo "Starting Hermes messaging gateway..."
        echo "  Ports: API=8642, Webhook=8644"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Jika baru pertama kali, buka Terminal di"
        echo "  EasyPanel dan jalankan:  hermes setup"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        exec hermes gateway
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
        echo "  hermes setup   → Setup wizard"
        echo "  hermes gateway → Start messaging gateway"
        echo "  hermes         → Interactive CLI"
        exec sleep infinity
        ;;
    *)
        exec "$@"
        ;;
esac
