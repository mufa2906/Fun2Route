# FunRoute — Product Overview

> Dokumen ini diperbarui setiap ada update signifikan pada produk.  
> **Versi terakhir:** Mei 2026 (rev 4)

---

## Apa itu FunRoute?

FunRoute adalah aplikasi mobile untuk **menghasilkan rute jalan/lari secara otomatis** dari lokasi pengguna saat ini, lalu memandu mereka selama aktivitas berlangsung secara real-time. Tujuannya sederhana: pengguna tinggal pilih jenis aktivitas dan target jarak atau durasi, lalu aplikasi yang mencarikan rute — tidak perlu mikirin mau lewat mana.

---

## Untuk Siapa?

Individu yang ingin berolahraga di luar ruangan (jalan santai, jalan cepat, atau lari) tapi malas atau tidak tahu harus lewat rute mana. Cocok untuk yang ingin target jarak atau durasi tertentu tanpa perencanaan rute manual.

---

## Platform

- **Android** — utama, termasuk background location tracking
- **iOS** — didukung via Expo

---

## Fitur Utama

### 1. Generate Rute Otomatis

Dari layar utama, pengguna memilih:

- **Jenis Aktivitas:** Jalan Santai (4 km/h) | Jalan Cepat (5.5 km/h) | Lari Ringan (8 km/h)
- **Mode Target:** Jarak (1, 2, 3, 5, 7, 10 km) ATAU Durasi (15, 20, 30, 45, 60, 90 menit)
- **Input manual** — ketik nilai sembarang di kolom teks (misal 1.5 km atau 25 menit)
- **Loop toggle** — "Kembali ke titik awal" ON/OFF

Jika mode **Durasi** dipilih, target jarak dihitung otomatis berdasarkan kecepatan default aktivitas:

```
targetDistanceM = (kecepatan_km_h × menit) / 60 × 1000
```

Rute dihasilkan **client-side** via OSRM public API — tidak memerlukan server tambahan.

---

### 2. Pilih Titik Tujuan (Opsional)

Saat loop OFF, pengguna dapat mengetuk peta untuk memilih titik tujuan/stop kustom:

- **One-way:** rute langsung dari posisi pengguna ke titik yang dipilih
- **Loop:** rute melewati titik yang dipilih lalu kembali ke awal (3 kandidat dengan variasi jalur kembali)

Titik yang dipilih ditandai dengan **pin oranye** di peta.

---

### 3. Pemilihan Rute

Setelah generate, pengguna melihat beberapa opsi rute di peta (ditampilkan sebagai polyline). Setiap rute menampilkan:
- Estimasi jarak aktual
- Estimasi durasi berdasarkan kecepatan aktivitas
- Preview jalur di peta Mapbox

Jika jarak rute yang tersedia berbeda **>20%** dari target yang diminta (karena keterbatasan jaringan jalan), muncul **banner peringatan kuning** yang menjelaskan selisih jaraknya.

Pengguna memilih satu rute, lalu mulai navigasi.

---

### 4. Navigasi Real-Time

Selama aktivitas berjalan:
- Peta mengikuti posisi pengguna secara otomatis (*camera follow*)
- Rute rencana ditampilkan sebagai **garis dashed abu-abu**
- Track yang sudah dilalui ditampilkan sebagai **garis solid oranye**
- Saat navigasi **loop**: **pin hijau** muncul di titik start/finish agar pengguna tahu persis harus kembali ke mana
- Jarak, waktu aktif, kalori, dan pace ditampilkan secara live

**Auto-Pause:** Jika pengguna berhenti bergerak lebih dari 60 detik (kecepatan < 0.5 m/s), aktivitas otomatis di-pause.

**Off-Route Detection:** Jika pengguna melenceng dari rute:
- Jalan: > 40 meter
- Lari: > 65 meter

**Loop Arrival Detection:** Saat navigasi loop, setelah menempuh ≥55% rute dan berada dalam radius 45m dari titik awal, muncul alert "Hampir Selesai!" yang menawarkan untuk mengakhiri aktivitas. Banner **"🏁 X m ke titik start"** muncul di bawah stats setelah >50% rute untuk membantu pengguna tahu jarak sisa ke finish.

---

### 5. Tandai Lokasi (POI & Zona Hindari)

Selama navigasi, pengguna dapat mengetuk tombol **"📍 Tandai"** untuk menandai lokasi saat ini dengan salah satu kategori:
- **Lokasi Menarik** — tersimpan sebagai POI di SQLite lokal
- **Hindari - Ramai Motor** — tersimpan sebagai zona hindari di SQLite lokal
- **Hindari - Tanpa Trotoar** — tersimpan sebagai zona hindari di SQLite lokal
- Catatan kustom opsional

Data ini tersimpan lokal dan akan digunakan sebagai avoidance zones di iterasi generate rute berikutnya.

---

### 6. Background Tracking

Saat aplikasi diminimize, GPS tracking tetap berjalan via background location service. Lokasi yang masuk saat background disimpan sementara di SQLite lokal (`location_queue`) dan di-drain kembali saat aplikasi kembali aktif.

Android menampilkan persistent notification selama tracking aktif:
> *"FunRoute Active — Recording your route…"*

---

### 7. Riwayat Aktivitas

Setelah aktivitas selesai, pengguna dapat menyimpan rekaman ke Supabase. Layar riwayat menampilkan:
- **Ringkasan mingguan** — total jarak, waktu, dan jumlah aktivitas minggu ini
- **Daftar aktivitas** — per sesi dengan jarak, waktu, dan kalori

---

### 8. Autentikasi

Pengguna bisa:
- **Login / Daftar** dengan email dan password
- **Lewati** dan masuk sebagai tamu (guest mode) — riwayat tidak tersimpan ke akun

---

## Izin yang Dibutuhkan

| Izin | Kapan Diminta | Keperluan |
|------|--------------|-----------|
| **Location (Foreground)** | Saat pertama buka app | Deteksi lokasi & navigasi |
| **Location (Background)** | Setelah foreground diizinkan | Tracking saat app diminimize |

Jika izin foreground ditolak → layar informasi ditampilkan.  
Jika izin background ditolak → navigasi tetap jalan, tapi tracking berhenti saat app diminimize.

---

## Fitur yang Direncanakan

- **Profil & Berat Badan** — saat ini berat badan default 70 kg untuk semua pengguna
- **Avoidance zones dari SQLite** — data POI/hindari yang sudah dikumpulkan belum diintegrasikan ke route engine

---

## Riwayat Update

### Mei 2026 (rev 4) — Navigasi Loop & UX
- Pin hijau start/finish di peta saat navigasi loop
- Rute rencana jadi dashed, track dilalui solid oranye
- Banner "🏁 X m ke titik start" real-time setelah >50% rute

### Mei 2026 (rev 3) — Pilih Titik Tujuan & Konfirmasi Jarak
- Tap peta untuk pilih titik tujuan/stop kustom (one-way & loop via waypoint)
- Banner peringatan kuning jika jarak rute berbeda >20% dari target
- Loop arrival detection: alert otomatis saat kembali ke titik awal
- Fix loop closure: polyline loop tertutup sempurna
- Fix UI: semua warna biru `#2563EB` → orange `#FF5C35`

### Mei 2026 (rev 2) — Route Engine & POI
- Route generation dipindah client-side via OSRM (hapus Supabase Edge Function)
- Refaktor engine ke modul terpisah: waypoint generator, calibrator, fingerprint, scorer
- 6 preset jarak (1–10 km) dan 6 preset durasi (15–90 min) dengan horizontal scroll
- Input manual untuk nilai kustom
- Loop toggle "Kembali ke titik awal"
- Fitur "Tandai Lokasi" (POI & zona hindari) selama navigasi
- Riwayat aktivitas dengan ringkasan mingguan
- Fix kalkulasi durasi menggunakan kecepatan aktivitas yang dipilih

### Mei 2026 (rev 1) — Fondasi Aplikasi
- Auth email/password + mode tamu via Supabase
- Layar izin GPS foreground dan background
- Layar utama: pilih aktivitas, jarak/durasi, generate rute
- Peta Mapbox dengan lokasi user real-time
- LocationService: GPS smoothing, auto-pause, off-route detection, background tracking via SQLite queue
- State management: Zustand (auth, route, navigation)
- Analytics: PostHog
