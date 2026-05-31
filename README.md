# Hermes Agent — Easypanel Deployment (ARM64)

Deploy [Hermes Agent](https://github.com/NousResearch/hermes-agent) by NousResearch ke **Easypanel** menggunakan Docker pada arsitektur **ARM64**.

## Arsitektur

```
┌──────────────────────────────────────────────┐
│                  Easypanel                    │
│  ┌──────────────────────────────────────────┐ │
│  │         Hermes Agent Container           │ │
│  │                                          │ │
│  │  s6-overlay (PID 1 — process supervisor) │ │
│  │  ├── hermes gateway (AI agent)           │ │
│  │  ├── dashboard (:9119)                   │ │
│  │  └── API server (:8642)                  │ │
│  │                                          │ │
│  │  Volume: /opt/data (persistent state)    │ │
│  └────────────┬───────────┬─────────────────┘ │
│          port 8642    port 9119               │
│          (API)        (Dashboard)             │
└──────────────────────────────────────────────┘
```

## Quick Start

### 1. Clone & Configure

```bash
git clone <repo-url> hermes-agent
cd hermes-agent
cp .env.example .env
```

Edit `.env` dan isi `API_SERVER_KEY` dengan key yang kuat:

```bash
# Generate random key
openssl rand -hex 32
```

### 2. Initial Setup (Interactive)

Jalankan setup wizard untuk konfigurasi LLM provider dan messaging:

```bash
docker compose run --rm hermes setup
```

Wizard akan memandu Anda untuk:
- Memilih LLM provider dan model
- Memasukkan API key
- Mengkonfigurasi messaging channel (opsional)

### 3. Start Gateway

```bash
docker compose up -d
```

### 4. Verifikasi

```bash
# Cek status container
docker compose ps

# Cek logs
docker compose logs -f hermes

# Health check
curl http://localhost:8642/health
```

Dashboard tersedia di: `http://localhost:9119`

---

## Deploy ke Easypanel

### Metode 1: Via Git Repository

1. Push repo ini ke GitHub/GitLab
2. Di Easypanel, buat project baru → **App** → **Docker Compose**
3. Connect ke repository
4. Tambahkan environment variables di Easypanel UI (dari `.env.example`)
5. Deploy

### Metode 2: Via Docker Image Langsung

1. Di Easypanel, buat project baru → **App** → **Docker**
2. Image: `nousresearch/hermes-agent:latest`
3. Konfigurasi:
   - **Ports**: `8642`, `9119`
   - **Volumes**: `/opt/data` → persistent volume
   - **Environment Variables**: (dari `.env.example`)
   - **Command**: `gateway run`
   - **Restart Policy**: `unless-stopped`
4. Deploy

### Konfigurasi Domain di Easypanel

- **Dashboard**: Assign domain ke port `9119`
- **API Server**: Assign domain ke port `8642` (opsional)
- Easypanel otomatis menangani SSL via Let's Encrypt

---

## Environment Variables

| Variable | Deskripsi | Default |
|----------|-----------|---------|
| `HERMES_DASHBOARD` | Aktifkan web dashboard | `1` |
| `HERMES_DASHBOARD_HOST` | Bind address dashboard | `0.0.0.0` |
| `HERMES_DASHBOARD_PORT` | Port dashboard | `9119` |
| `HERMES_DASHBOARD_INSECURE` | Skip OAuth gate (Easypanel handles auth) | `1` |
| `API_SERVER_ENABLED` | Aktifkan API server | `true` |
| `API_SERVER_HOST` | Bind address API | `0.0.0.0` |
| `API_SERVER_KEY` | API authentication key (min 8 chars) | *(wajib diisi)* |
| `API_SERVER_CORS_ORIGINS` | Allowed CORS origins | `*` |
| `HERMES_UID` / `PUID` | UID user di container | `10000` |
| `HERMES_GID` / `PGID` | GID user di container | `10000` |

Lihat `.env.example` untuk daftar lengkap LLM provider dan tool API keys.

---

## Persistent Data

Semua state Hermes disimpan di volume `/opt/data`:

| Path | Isi |
|------|-----|
| `.env` | API keys dan secrets |
| `config.yaml` | Konfigurasi Hermes |
| `SOUL.md` | Personality agent |
| `sessions/` | Riwayat percakapan |
| `memories/` | Persistent memory |
| `skills/` | Installed skills |
| `cron/` | Scheduled jobs |
| `logs/` | Runtime logs |

> ⚠️ **Jangan jalankan dua gateway container** pada data directory yang sama secara bersamaan.

---

## Management Commands

```bash
# Interactive chat
docker compose exec hermes hermes

# Single query
docker compose exec hermes hermes chat -q "Hello, Hermes!"

# Change model/provider
docker compose exec hermes hermes model

# Re-run setup wizard
docker compose exec hermes hermes setup

# Check health
docker compose exec hermes hermes doctor

# Create additional profile
docker compose exec hermes hermes profile create coder

# Start profile gateway
docker compose exec hermes hermes -p coder gateway start

# View gateway status
docker compose exec hermes hermes gateway status
```

---

## Troubleshooting

### Container tidak bisa start

```bash
# Cek logs
docker compose logs hermes

# Cek apakah port sudah digunakan
docker compose ps
netstat -tlnp | grep -E '8642|9119'
```

### Permission denied pada volume

Set UID/GID di `.env`:

```bash
# Di host, cek UID/GID Anda
id -u  # → HERMES_UID
id -g  # → HERMES_GID
```

### Dashboard tidak bisa diakses

1. Pastikan `HERMES_DASHBOARD=1` di environment
2. Pastikan port `9119` di-expose
3. Cek logs: `docker compose logs hermes | grep dashboard`

### ARM64 compatibility

Image `nousresearch/hermes-agent:latest` sudah mendukung ARM64 secara native.
Jika build gagal, pastikan Docker BuildKit aktif:

```bash
export DOCKER_BUILDKIT=1
docker compose build
```

---

## Referensi

- [Hermes Agent GitHub](https://github.com/NousResearch/hermes-agent)
- [Hermes Agent Docker Guide](https://hermes.nousresearch.com/user-guide/docker)
- [Easypanel Documentation](https://easypanel.io/docs)
