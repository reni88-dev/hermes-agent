# Hermes Agent — Easypanel Deployment (ARM64)

Deploy [Hermes Agent](https://github.com/NousResearch/hermes-agent) ke **Easypanel** pada arsitektur **ARM64**.

## Cara Kerja

Container di-deploy dalam kondisi **idle** (tidak menjalankan service apapun). Semua konfigurasi dilakukan secara manual via terminal Easypanel.

## Deploy ke Easypanel

### 1. Buat App di Easypanel

1. Masuk ke Easypanel dashboard
2. Buat **Project** baru (atau gunakan project yang ada)
3. Klik **+ Service** → pilih **App**
4. Pilih **GitHub** sebagai source
5. Hubungkan ke repository ini, pilih branch yang sesuai
6. Easypanel akan mendeteksi `Dockerfile` dan mulai build

### 2. Konfigurasi di Easypanel

Sebelum atau sesudah deploy:

- **Volumes**: Tambahkan mount `/opt/data` ke persistent volume
- **Environment Variables** (opsional, bisa ditambahkan nanti):
  - `TZ` = `Asia/Jakarta` (sudah di-set di Dockerfile)

### 3. Deploy

Klik **Deploy**. Container akan build dan berjalan dalam kondisi idle.

### 4. Setup Hermes (Pertama Kali)

1. Buka **Terminal** di Easypanel (tab terminal pada service)
2. Jalankan setup wizard:

```bash
hermes setup
```

3. Wizard akan memandu Anda untuk:
   - Memilih LLM provider dan model
   - Memasukkan API key
   - Mengkonfigurasi messaging channel (Telegram, dll)

### 5. Jalankan Gateway

Setelah setup selesai, **restart container** di Easypanel.
Container akan otomatis mendeteksi config dan menjalankan gateway.

> **Cara kerja auto-start:**
> - Entrypoint mengecek apakah `/opt/data/config.yaml` ada
> - Jika ada → `hermes gateway run` otomatis dijalankan
> - Jika belum → container idle, menunggu `hermes setup`
> - Setiap container restart → gateway otomatis jalan kembali

---

## Perintah Berguna (via Terminal Easypanel)

```bash
# Setup wizard (pertama kali)
hermes setup

# Interactive chat
hermes

# Single query
hermes chat -q "Hello!"

# Ganti model/provider
hermes model

# Jalankan gateway (Telegram/Discord/dll)
hermes gateway run

# Cek status
hermes doctor

# Lihat bantuan
hermes --help
```

## Persistent Data

Semua data Hermes disimpan di `/opt/data`:

| Path | Isi |
|------|-----|
| `.env` | API keys dan secrets |
| `config.yaml` | Konfigurasi Hermes |
| `SOUL.md` | Personality agent |
| `sessions/` | Riwayat percakapan |
| `memories/` | Persistent memory |
| `skills/` | Installed skills |

## Referensi

- [Hermes Agent GitHub](https://github.com/NousResearch/hermes-agent)
- [Hermes Docker Guide](https://hermes.nousresearch.com/user-guide/docker)
- [Easypanel Docs](https://easypanel.io/docs)
