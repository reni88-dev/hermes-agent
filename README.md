# Hermes Agent — Docker Deployment untuk EasyPanel (ARM64)

Deploy [Hermes Agent](https://github.com/NousResearch/hermes-agent) di server ARM64 menggunakan EasyPanel.

## 📁 File yang Disertakan

| File | Fungsi |
|------|--------|
| `Dockerfile` | Multi-stage build, ARM64-compatible |
| `entrypoint.sh` | Startup script dengan beberapa mode |
| `docker-compose.yml` | Orchestration + volume persistensi |
| `.env.example` | Template environment variables |

## 🚀 Deploy via EasyPanel

### Langkah 1: Upload ke Git Repository

Push semua file ini ke repository Git (GitHub, GitLab, dll):

```bash
git init
git add .
git commit -m "Initial Hermes Agent deployment"
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
- **Mount Path**: `/root/.hermes`
- **Name**: `hermes-data`

#### Ports (Opsional — jika mau pakai API/Webhook)
- `8642` → API Server
- `8644` → Webhook Server

#### Environment Variables
Tambahkan minimal:
- `TZ` = `Asia/Jakarta`

> Variable lainnya bisa dikonfigurasi via `hermes setup` di terminal.

### Langkah 4: Setup Pertama Kali

Setelah container berjalan:

1. Buka **EasyPanel** → pilih service → tab **Terminal**
2. Jalankan:
   ```bash
   hermes setup
   ```
3. Ikuti wizard interaktif untuk:
   - Memilih LLM provider (OpenRouter, Anthropic, OpenAI, dll)
   - Memasukkan API key
   - Mengkonfigurasi model

### Langkah 5: Mulai Pakai

Setelah setup selesai, Anda bisa langsung di terminal:

```bash
# Chat langsung di terminal
hermes

# Atau jalankan messaging gateway (Telegram, Discord, dll)
hermes gateway setup    # Setup messaging platform
hermes gateway          # Start gateway
```

## 🌟 Konfigurasi Lanjutan (Advanced Setup)

Berdasarkan *Best Practices* dari dokumentasi resmi Hermes, Anda bisa mengaktifkan beberapa fitur tingkat lanjut untuk keamanan dan efisiensi resource:

### 1. Keamanan Terminal: Eksekusi Terisolasi (Docker-in-Docker)
Secara bawaan, agen cerdas ini akan mengeksekusi perintah terminal (seperti `pip install`, `ls`, dll.) **langsung di dalam** container utamanya. Ini agak berisiko jika ia tak sengaja merusak sistemnya sendiri saat bertingkah.
Untuk mencegah hal tersebut, Anda bisa memaksa agen agar menjalankan *terminal commands* di sebuah sub-container terpisah:
1. Buka konfigurasi **Volumes** di aplikasi EasyPanel Anda.
2. Tambahkan volume tipe *Bind Mount*:
   - Source path (Host): `/var/run/docker.sock`
   - Destination path (Container): `/var/run/docker.sock`
   *(Atau cukup hapus tanda pagar `#` pada baris /var/run/docker.sock di file `docker-compose.yml` sebelum mengupload ke Github)*
3. Tambahkan di menu **Environment**: `TERMINAL_ENV=docker`
4. Deploy ulang. Sekarang setiap perintah berbahaya akan diisolasi Hermes di container mini sementaranya!

### 2. Mematikan Headless Browser Lokal (Penghemat RAM)
Jika RAM server VPS Anda terbatas, tugas mendownload dan *scraping web browser* Playwright akan sangat memberatkan. 
Hermes mendukung delegasi penjelajahan internet via *Cloud API* ke **Browserbase**:
1. Buat akun di browserbase.com untuk mendapatkan API.
2. Tambahkan keys ini ke **Environment** pada EasyPanel:
   - `BROWSERBASE_API_KEY=key_anda_di_sini`
   - `BROWSERBASE_PROJECT_ID=id_anda_di_sini`
Kini proses baca dokumen/web akan berjalan sangat ringan di server Anda!

## 🔄 Mode Container

Entrypoint mendukung beberapa mode via Docker command:

| Command | Fungsi |
|---------|--------|
| `sleep` | **(Default)** Container standby, setup via terminal |
| `gateway` | Langsung jalankan messaging gateway |
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
/root/.hermes/
├── config.yaml          # Pengaturan utama
├── .env                 # API keys & secrets
├── auth.json            # OAuth credentials
├── SOUL.md              # Personality agent
├── memories/            # Memory persistensi
├── skills/              # Skills agent
├── cron/                # Scheduled jobs
├── sessions/            # Gateway sessions
└── logs/                # Log files
```

Semua file di atas tersimpan di volume `hermes-data`, sehingga aman dari rebuild container.

## ⚠️ Catatan Penting

- **ARM64**: Dockerfile ini dirancang untuk server ARM64. Jika menggunakan x86_64, hapus `platform: linux/arm64` dari docker-compose.yml
- **Build time**: Build pertama memerlukan waktu ~10-15 menit karena menginstall banyak dependencies
- **Playwright**: Browser Chromium diinstall untuk fitur web browsing agent. Jika tidak diperlukan, baris terkait bisa dihapus dari Dockerfile untuk memperkecil image
