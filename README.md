# Hermes Agent v0.15.2 — Docker Deployment untuk EasyPanel

Deploy [Hermes Agent](https://github.com/NousResearch/hermes-agent) v0.15.2 ("Velocity Release") di server menggunakan EasyPanel.

## ✨ Yang Baru di v0.15.x

| Fitur | Deskripsi |
|-------|-----------|
| **Swarm/Kanban** | Multi-agent orchestration via `hermes kanban swarm` |
| **MCP Catalog** | Built-in catalog integrasi: `hermes mcp catalog` |
| **Profile System** | Multi-profile terisolasi: `hermes profile create/use/list` |
| **Dashboard** | Web dashboard bawaan (supervised oleh s6-overlay) |
| **Bitwarden** | Secrets management via single bootstrap token |
| **Promptware Defense** | Anti-brainworm prompt injection filter |
| **Performance** | Cold-start < 1 detik, session search 4.500x lebih cepat |

## 📁 File yang Disertakan

| File | Fungsi |
|------|--------|
| `Dockerfile` | Single-stage Debian 13.4 + s6-overlay, multi-arch (amd64/arm64) |
| `entrypoint.sh` | Startup wrapper script (dikelola s6-overlay sebagai PID 1) |
| `docker-compose.yml` | Orchestration + volume persistensi |
| `.env.example` | Template environment variables |

## 🏗️ Perubahan Arsitektur dari Versi Sebelumnya

> **⚠️ PENTING:** Jika Anda meng-upgrade dari versi sebelumnya (< v0.15.0), perhatikan perubahan ini:

| Aspek | Lama | Baru (v0.15.2) |
|-------|------|-----------------|
| Base Image | `python:3.11-slim-bookworm` multi-stage | `debian:13.4` (trixie) single-stage |
| PID 1 | Custom entrypoint.sh | **s6-overlay** `/init` |
| Python | 3.11 | **3.13** (via uv) |
| Runtime User | root | **`hermes`** (UID 10000) |
| Data Volume | `/root/.hermes` | **`/opt/data`** |
| Port | 8642 (API) + 8644 (Webhook) | **8642 saja** (consolidated) |
| Node.js | Nodesource install | Copy dari official `node:22` image |

### Migrasi Data Volume

Jika sudah ada data dari versi lama:

```bash
# 1. Backup data lama
docker cp hermes-agent:/root/.hermes ./hermes-backup

# 2. Rebuild container baru
docker compose down
docker compose build --no-cache
docker compose up -d

# 3. Copy data ke volume baru
docker cp ./hermes-backup/. hermes-agent:/opt/data/
```

## 🚀 Deploy via EasyPanel

### Langkah 1: Upload ke Git Repository

Push semua file ini ke repository Git (GitHub, GitLab, dll):

```bash
git init
git add .
git commit -m "Hermes Agent v0.15.2 deployment"
git remote add origin https://github.com/username/hermes-agent-deploy.git
git push -u origin main
```

### Langkah 2: Buat Service di EasyPanel

1. Buka **EasyPanel** → **Create Service** → **App**
2. Pilih **Source**: GitHub (atau Git repository lainnya)
3. Hubungkan ke repository yang sudah di-push
4. **Build method**: Dockerfile
5. Klik **Deploy**

### Langkah 3: Konfigurasi di EasyPanel

#### Volumes (Wajib!)
Tambahkan volume mount untuk menyimpan data persistensi:
- **Mount Path**: `/opt/data`
- **Name**: `hermes-data`

> ⚠️ Path volume **berubah** dari `/root/.hermes` ke `/opt/data` di v0.15.2

#### Ports
- `8642` → API Server + Dashboard + Webhook (semua consolidated di satu port)

#### Environment Variables
Tambahkan minimal:
- `TZ` = `Asia/Jakarta`
- `HERMES_UID` = `1000` *(opsional, untuk fix ownership volume)*
- `HERMES_GID` = `1000` *(opsional, untuk fix ownership volume)*

> Variable lainnya bisa dikonfigurasi via `hermes setup` di terminal.

### Langkah 4: Setup Pertama Kali

Setelah container berjalan:

1. Buka **EasyPanel** → pilih service → tab **Terminal**
2. Jalankan:
   ```bash
   hermes setup
   ```
3. Ikuti wizard interaktif untuk:
   - Memilih LLM provider (OpenRouter, Anthropic, OpenAI, Nous Portal, dll)
   - Memasukkan API key
   - Mengkonfigurasi model

### Langkah 5: Mulai Pakai

Setelah setup selesai, Anda bisa langsung di terminal:

```bash
# Chat langsung di terminal
hermes

# Jalankan messaging gateway (Telegram, Discord, dll)
hermes gateway setup    # Setup messaging platform
hermes gateway          # Start gateway (supervised oleh s6-overlay)

# ─── Fitur Baru v0.15.x ───

# Multi-agent swarm orchestration
hermes kanban swarm     # Buat swarm topology lengkap

# MCP integrations catalog
hermes mcp catalog      # Browse & install MCP servers (n8n, Linear, GitHub, dll)
hermes mcp add <name>   # Tambah MCP server
hermes mcp list         # List MCP servers yang terkonfigurasi

# Profile management (multi-instance)
hermes profile create <name>  # Buat profile baru
hermes profile use <name>     # Switch ke profile
hermes profile list           # List semua profile
```

## 🌟 Konfigurasi Lanjutan (Advanced Setup)

Berdasarkan *Best Practices* dari dokumentasi resmi Hermes v0.15.2:

### 1. Keamanan Terminal: Eksekusi Terisolasi (Docker-in-Docker)
Secara bawaan, agen cerdas ini akan mengeksekusi perintah terminal **langsung di dalam** container utamanya. Untuk mencegah kerusakan jika ia tak sengaja merusak sistemnya sendiri:

1. Buka konfigurasi **Volumes** di aplikasi EasyPanel Anda.
2. Tambahkan volume tipe *Bind Mount*:
   - Source path (Host): `/var/run/docker.sock`
   - Destination path (Container): `/var/run/docker.sock`
   *(Atau cukup hapus tanda pagar `#` pada baris /var/run/docker.sock di file `docker-compose.yml` sebelum mengupload ke Github)*
3. Tambahkan di menu **Environment**: `TERMINAL_ENV=docker`
4. Deploy ulang. Sekarang setiap perintah berbahaya akan diisolasi Hermes di container mini sementaranya!

### 2. Mematikan Headless Browser Lokal (Penghemat RAM)
Jika RAM server VPS Anda terbatas, Playwright Chromium akan memberatkan.
Hermes mendukung delegasi via *Cloud API* ke **Browserbase**:
1. Buat akun di browserbase.com untuk mendapatkan API.
2. Tambahkan keys ini ke **Environment** pada EasyPanel:
   - `BROWSERBASE_API_KEY=key_anda_di_sini`
   - `BROWSERBASE_PROJECT_ID=id_anda_di_sini`
Kini proses baca dokumen/web akan berjalan sangat ringan di server Anda!

### 3. Bitwarden Secrets Manager (Baru di v0.15.x!)
Ganti semua API key terpisah dengan satu bootstrap token:
1. Buat akun di [Bitwarden Secrets Manager](https://bitwarden.com/products/secrets-manager/)
2. Simpan semua API keys Anda di vault Bitwarden
3. Tambahkan satu variable environment:
   - `BWS_ACCESS_TOKEN=your-bootstrap-token`
4. Hermes akan otomatis resolve semua secrets dari vault

### 4. s6-overlay Service Management
Karena s6-overlay mengelola services di dalam container, Anda bisa memeriksa dan mengelola via terminal:

```bash
# Cek status gateway
docker exec hermes-agent /command/s6-svstat /run/service/gateway-default

# Restart gateway
docker exec hermes-agent /command/s6-svc -t /run/service/gateway-default

# Lihat logs
docker exec hermes-agent cat /opt/data/logs/gateway.log
```

## 🔄 Mode Container

Entrypoint mendukung beberapa mode via Docker command:

| Command | Fungsi |
|---------|--------|
| `gateway` | **(Default)** Jalankan messaging gateway (supervised oleh s6) |
| `sleep` | Container standby, setup via terminal |
| `setup` | Langsung jalankan setup wizard |
| `cli` | Langsung masuk interactive CLI |
| `shell` | Masuk bash shell |

Untuk mengubah mode di EasyPanel, set **Docker Command** ke mode yang diinginkan.

**Contoh — langsung jalankan gateway setelah setup selesai:**
Ubah Docker Command dari `sleep` ke `gateway`.

## 📝 Konfigurasi Lanjutan

### Messaging Gateway

Setelah `hermes setup`, konfigurasi messaging:

```bash
hermes gateway setup    # Wizard untuk Telegram/Discord/Slack/WhatsApp
```

### Kanban & Swarm (Baru!)

```bash
hermes kanban init                   # Inisialisasi Kanban database
hermes kanban boards create <slug>   # Buat board baru
hermes kanban create "<title>"       # Buat task baru
hermes kanban swarm                  # Setup full Swarm v1 topology
hermes kanban dispatch               # Trigger task dispatching
```

### MCP Server Management (Baru!)

```bash
hermes mcp catalog          # Browse curated MCP catalog
hermes mcp add <name>       # Tambah MCP server
hermes mcp list             # List configured servers
hermes mcp test <name>      # Test koneksi
hermes mcp configure <name> # Toggle tool selection
hermes mcp serve            # Run Hermes sebagai MCP server
```

### Update Hermes Agent

```bash
hermes update
```

### Troubleshooting

```bash
hermes doctor           # Diagnosa masalah
hermes config           # Lihat konfigurasi saat ini
hermes config check     # Cek opsi yang belum dikonfigurasi
```

### Lokasi File Konfigurasi (dalam Container)

```
/opt/data/
├── config.yaml          # Pengaturan utama
├── .env                 # API keys & secrets
├── auth.json            # OAuth credentials
├── SOUL.md              # Personality agent
├── memories/            # Memory persistensi
├── skills/              # Skills agent
├── cron/                # Scheduled jobs
├── sessions/            # Gateway sessions
├── profiles/            # Multi-profile data (BARU!)
├── logs/                # Log files
└── hooks/               # Event hooks
```

Semua file di atas tersimpan di volume `hermes-data` (`/opt/data`), sehingga aman dari rebuild container.

## ⚠️ Catatan Penting

- **Multi-arch**: Dockerfile ini mendukung **amd64** dan **arm64** secara otomatis via BuildKit `TARGETARCH`. Tidak perlu set `platform` manual.
- **Non-root**: Container berjalan sebagai user `hermes` (UID 10000). Gunakan `HERMES_UID` / `HERMES_GID` jika perlu menyesuaikan ownership volume.
- **s6-overlay**: PID 1 dikelola oleh s6-overlay, bukan shell script. Ini menjamin zombie process reaping, auto-restart, dan proper signal handling.
- **Build time**: Build pertama memerlukan waktu ~10-15 menit karena menginstall banyak dependencies.
- **Playwright**: Browser Chromium diinstall untuk fitur web browsing agent. Jika tidak diperlukan, baris terkait bisa dihapus dari Dockerfile untuk memperkecil image.
- **Resource**: Disarankan minimal **2 vCPU dan 4 GB RAM** untuk production, terutama jika menggunakan browser automation.
