# FunRoute — Functional Flow Diagrams

> Diagram alur per fitur. Dibaca dari atas ke bawah.  
> Render otomatis di GitHub, VS Code (Mermaid extension), dan GitLab.

---

## 1. Onboarding & Auth

```mermaid
flowchart TD
    A([App dibuka]) --> B[_layout.tsx: init auth\nsupabase.auth.getSession]

    B --> C{Session ada?}

    C -- Ya --> D[Redirect ke app/index]
    C -- Tidak --> E[Redirect ke auth/login]

    D --> F{Izin GPS\nsudah granted?}
    F -- Ya --> G([Home Screen])
    F -- Tidak --> H[Redirect ke /permission]

    E --> I[Layar Login / Daftar]
    I --> J{User pilih}
    J --> K[Login dengan email]
    J --> L[Daftar akun baru]
    J --> M[Lewati / Mode Tamu]

    K --> N[supabase.auth.signInWithPassword]
    L --> O[supabase.auth.signUp]
    N & O --> P{Berhasil?}
    P -- Ya --> H
    P -- Gagal --> Q[Tampilkan error]
    Q --> I

    M --> H
```

---

## 2. Permintaan Izin GPS

```mermaid
flowchart TD
    A([Layar /permission]) --> B[Cek status izin foreground]

    B --> C{Sudah granted?}
    C -- Ya --> D[Minta izin background]
    C -- Tidak --> E[Tampilkan penjelasan izin foreground]

    E --> F[User tap Izinkan]
    F --> G[requestForegroundPermissionsAsync]
    G --> H{Granted?}
    H -- Ya --> D
    H -- Tidak --> I[Layar: izin ditolak\nbutton Buka Pengaturan]

    D --> J[Tampilkan penjelasan izin background]
    J --> K[User tap Izinkan]
    K --> L[requestBackgroundPermissionsAsync]
    L --> M{Granted?}
    M -- Ya --> N([Redirect ke Home Screen])
    M -- Tidak --> N
```

---

## 3. Generate Rute (Client-Side OSRM)

```mermaid
flowchart TD
    A([Home Screen terbuka]) --> B[LocationService.startIdleWatching]
    B --> C[GPS update setiap 10m\nakurasi < 25m]
    C --> D[setUserLocation → tombol aktif]

    D --> E[User pilih aktivitas\nJalan Santai / Cepat / Lari]
    E --> F{Mode target}

    F --> G[Jarak\n1/2/3/5/7/10 km\natau input manual]
    F --> H[Durasi\n15/20/30/45/60/90 mnt\natau input manual]

    H --> I[Hitung targetDistanceM\nkecepatan × menit / 60 × 1000]
    G --> J[targetDistanceM = jarak yang dipilih]
    I --> J

    J --> K{isLoop?}
    K -- ON --> L[Loop: waypoints segitiga\nbearing 3 arah]
    K -- OFF + ada titik tujuan --> M[generateRouteThroughPoint\nke waypoint kustom]
    K -- OFF --> N[One-way: waypoints lurus\nbearing 3 arah]

    L & N --> O[OSRM Pass 1: jarak awal]
    O --> P[Scale waypoints agar ≈ target]
    P --> Q[OSRM Pass 2: jarak hasil]
    M --> R

    Q --> R[Deduplikasi fingerprint\nSort by akurasi]
    R --> S[router.push ke route-selection\nparams: lat, lng, targetDistanceM,\nactivityType, isLoop, destLat?, destLng?]
```

---

## 4. Pilih Titik Tujuan (Opsional)

```mermaid
flowchart TD
    A([Home Screen, isLoop = OFF]) --> B[Tombol Pilih titik tujuan muncul]

    B --> C[User tap tombol]
    C --> D[Mode picking aktif:\nbanner oranye muncul di peta]

    D --> E[User tap titik di peta]
    E --> F[onPressCoord dipanggil\nMapView.onPress → koordinat]
    F --> G[setDestination lat/lng\nPin oranye muncul di peta]

    G --> H[User tap Buat Rute]
    H --> I[Kirim destLat, destLng\nke route-selection]
    I --> J[generateRouteThroughPoint\nbukan generateRoutes]

    B --> K[User tidak pilih tujuan]
    K --> L[generateRoutes biasa]
```

---

## 5. Pemilihan Rute & Mulai Navigasi

```mermaid
flowchart TD
    A([Layar Route Selection]) --> B{Ada destLat/destLng?}

    B -- Ya --> C[generateRouteThroughPoint]
    B -- Tidak --> D[generateRoutes]

    C & D --> E[Render kandidat rute\nsebagai polyline di Mapbox]

    E --> F{Selisih jarak\n> 20% dari target?}
    F -- Ya --> G[Tampilkan banner kuning:\nJarak tersedia ≈ X km\nkamu minta Y km]
    F -- Tidak --> H

    G --> H[User tap salah satu rute]
    H --> I[setActiveRoute]
    I --> J[Rute dipilih di-highlight]

    J --> K[User tap Mulai Navigasi]
    K --> L[router.push ke navigation\nparams: routeId, activityType, isLoop]

    L --> M[Layar Navigasi]
    M --> N[LocationService.startNavigationTracking]
    N --> O[startBackgroundTracking\nforeground service notification]

    O --> P([Navigasi aktif])
```

---

## 6. Navigasi Real-Time & GPS Tracking

```mermaid
flowchart TD
    A([Navigasi aktif]) --> B[LocationService.startNavigationTracking]

    B --> C[Setiap update GPS]
    C --> D{Akurasi < 25m?}
    D -- Tidak --> C
    D -- Ya --> E[Masuk buffer 5 titik]

    E --> F[Smooth: rata-rata lat/lng]
    F --> G[Hitung speed dari expo-location]

    G --> H{speed < 0.5 m/s?}
    H -- Ya --> I[Tambah ke lowSpeedMs]
    H -- Tidak --> J[Reset lowSpeedMs]

    I --> K{lowSpeedMs > 60 detik?}
    K -- Ya --> L[onAutoPause → setState auto_paused]
    K -- Tidak --> M[Teruskan]

    J & M --> N[Hitung delta jarak\nhaversine dari titik sebelumnya]
    N --> O[onLocation → updateLocation]
    O --> P[Update peta, jarak, waktu]

    P --> Q{offRouteCounter = 3?}
    Q -- Tidak --> R[Increment counter]
    Q -- Ya --> S[Reset counter\nonOffRouteCheck]

    S --> T{Jarak ke rute aktif\n> threshold?}
    T -- Walk > 40m\nJog > 65m --> U[incrementOffRoute\nTampilkan peringatan]
    T -- Dalam batas --> C
    R --> C
```

---

## 7. Loop Arrival Detection

```mermaid
flowchart TD
    A([Navigasi loop aktif]) --> B[Setiap update currentLocation]

    B --> C{elapsedDistanceM\n≥ 55% route distance?}
    C -- Tidak --> B
    C -- Ya --> D[Hitung haversineM\nke koordinat pertama polyline]

    D --> E{Jarak ke start\n< 45m?}
    E -- Tidak --> B
    E -- Ya --> F[setArrivalAlerted = true]

    F --> G[Alert: Hampir Selesai! 🎉\nSelesaikan aktivitas?]

    G --> H{User pilih}
    H -- Lanjut Dulu --> B
    H -- Selesai --> I[handleFinish]
    I --> J([Layar Ringkasan])

    B --> K[Tampilkan banner hijau\n🏁 X m ke titik start\njika elapsedDist > 50% rute]
```

---

## 8. Background Tracking (App Diminimize)

```mermaid
flowchart TD
    A([App diminimize]) --> B[LocationService.startBackgroundTracking]

    B --> C[BACKGROUND_LOCATION_TASK aktif\nForeground service notification:\nFunRoute Active]

    C --> D[Setiap 5m ada update GPS]
    D --> E{Akurasi < 25m?}
    E -- Tidak --> D
    E -- Ya --> F[INSERT ke SQLite\nlocation_queue]

    F --> G[loop sampai app dibuka lagi]

    G --> H([App kembali ke foreground])
    H --> I[drainLocationQueue\nambil 50 baris terlama]
    I --> J[Proses ulang lokasi\nke NavigationStore]
    J --> K[DELETE dari queue]
    K --> L([State navigasi up-to-date])
```

---

## 9. Auto-Pause & Resume

```mermaid
flowchart TD
    A([Navigasi aktif]) --> B[Speed < 0.5 m/s\nterdeteksi]

    B --> C[Akumulasi lowSpeedMs]
    C --> D{> 60 detik?}
    D -- Tidak --> E[Lanjut tracking]
    D -- Ya --> F[onAutoPause dipanggil]

    F --> G[setState auto_paused]
    G --> H[Timer berhenti\nUI tampil badge Auto-Pause]

    H --> I[User bergerak lagi]
    I --> J[Speed > 0.5 m/s terdeteksi]
    J --> K[lowSpeedMs di-reset]
    K --> L{User pilih aksi?}

    L --> M[Resume otomatis\nstayState active]
    L --> N[User tap Resume manual\nsetState resumed → active]
    L --> O[User tap Selesai\nsetState finished]

    M & N --> A
    O --> P([Layar Ringkasan Aktivitas])
```

---

## 10. Tandai Lokasi (POI & Avoidance)

```mermaid
flowchart TD
    A([Navigasi aktif]) --> B[User tap 📍 Tandai]

    B --> C[Modal muncul\nTandai Lokasi Ini]

    C --> D{User pilih kategori}

    D --> E[Lokasi Menarik\nisAvoidance = false]
    D --> F[Hindari - Ramai Motor\nisAvoidance = true]
    D --> G[Hindari - Tanpa Trotoar\nisAvoidance = true]

    E & F & G --> H[Input catatan opsional]
    H --> I[User tap Simpan]

    I --> J{isAvoidance?}
    J -- Ya --> K[addAvoidance lat/lng/note\nSimpan ke SQLite avoidance_zones]
    J -- Tidak --> L[addPoi lat/lng/note\nSimpan ke SQLite pois]

    K & L --> M([Modal tutup, kembali navigasi])
```

---

## 11. Selesai Aktivitas & Simpan

```mermaid
flowchart TD
    A([setState finished]) --> B[LocationService.stopTracking]
    B --> C[stopBackgroundTracking]

    C --> D[Hitung ringkasan:\n- total jarak\n- durasi aktif\n- kalori\n- off-route count]

    D --> E[router.replace ke summary\nkirim params: jarak, waktu, kalori, breadcrumbs]

    E --> F([Layar Ringkasan])
    F --> G{User login?}

    G -- Tidak --> H[Tombol Kembali ke Beranda\nData tidak tersimpan]
    G -- Ya --> I[Tombol Simpan & Kembali]

    I --> J[supabase.from activity_sessions .insert\nlangsung ke DB, bukan Edge Function]

    J --> K{Berhasil?}
    K -- Ya --> L[useNavigationStore.reset]
    K -- Gagal --> M[Alert error\nCoba lagi]

    L --> N[router.replace ke Home]
```
