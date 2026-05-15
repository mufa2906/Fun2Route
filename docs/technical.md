# FunRoute — Technical Reference

> Dokumen ini untuk AI assistant dan developer. Baca sebelum mulai coding agar tidak salah asumsi.  
> **Last updated:** 2026-05-12 (rev 4)

---

## Tech Stack

| Layer | Teknologi | Catatan |
|-------|-----------|---------|
| Framework | Expo 54 + Expo Router 6 | File-based routing, React Native |
| Language | TypeScript 5.9 | Strict mode |
| Maps | **Mapbox** (`@rnmapbox/maps`) | Bukan Google Maps |
| Route Engine | **OSRM** public API | Client-side, tidak butuh server |
| Database / Auth | **Supabase** | PostgreSQL + Auth (Edge Functions sudah dihapus) |
| State | **Zustand 5** | 5 store: auth, route, navigation, poi, avoidance |
| Data Fetching | TanStack React Query v5 | Dipakai di history screen |
| GPS | expo-location + expo-task-manager | Foreground & background |
| Local Storage | expo-sqlite | Background queue + POI + avoidance zones |
| Secure Storage | expo-secure-store | Persistensi token Supabase |
| Analytics | **PostHog** React Native | Event tracking |
| Deploy | **EAS** (Expo Application Services) | |

---

## Struktur Folder

```
app/
├── _layout.tsx               — Root layout: QueryClientProvider, splash, auth init
├── index.tsx                 — Guard: redirect ke (auth) atau (app)
├── permission.tsx            — Layar izin GPS (foreground → background → denied)
├── (auth)/
│   ├── _layout.tsx           — Auth stack layout
│   └── login.tsx             — Login / daftar / mode tamu
└── (app)/
    ├── _layout.tsx           — App stack layout (protected)
    ├── index.tsx             — Home: peta + pilih aktivitas + destination tap + generate
    ├── route-selection.tsx   — Pilih kandidat rute + distance mismatch banner
    ├── navigation.tsx        — Navigasi real-time: stats, POI marking, arrival detection
    ├── summary.tsx           — Ringkasan aktivitas + simpan ke Supabase
    └── history.tsx           — Riwayat aktivitas (list + weekly summary)

src/
├── constants/
│   └── index.ts              — ⚠️ SUMBER KEBENARAN semua konstanta GPS & aktivitas
├── stores/
│   ├── useAuthStore.ts       — Session Supabase, login/signup/signout
│   ├── useRouteStore.ts      — Kandidat rute yang dihasilkan, rute aktif
│   ├── useNavigationStore.ts — State navigasi real-time (posisi, jarak, waktu, pause)
│   ├── usePoiStore.ts        — SQLite: point of interest yang ditandai user
│   └── useAvoidanceStore.ts  — SQLite: zona hindari yang ditandai user
├── services/
│   ├── gps/
│   │   └── LocationService.ts  — GPS tracking, smoothing, auto-pause, background queue
│   ├── routes/
│   │   └── RouteGenerator.ts   — Re-export generateRoutes & generateRouteThroughPoint
│   ├── supabase/
│   │   └── client.ts           — Supabase JS client + SecureStore adapter
│   └── analytics/
│       └── Analytics.ts        — PostHog wrapper
├── features/
│   └── routes/
│       └── engine/
│           ├── index.ts              — generateRoutes, generateRouteThroughPoint
│           ├── distance-calibrator.ts — fetchOsrmRoute, calibrateRoute (2-pass scaling)
│           ├── waypoint-generator.ts — buildWaypointsLoop, buildWaypointsOneWay
│           ├── route-fingerprint.ts  — makeFingerprint, deduplicateByFingerprint
│           └── route-scorer.ts       — sortByScore (urut berdasarkan akurasi jarak)
├── components/
│   └── MapView.tsx           — Mapbox map wrapper dengan semua props yang dibutuhkan
└── utils/
    └── geo.ts                — haversineM, offsetPoint, distanceToRouteM, formatDistance, dll
```

---

## Konstanta Kritis

File: [`src/constants/index.ts`](../src/constants/index.ts)

```ts
GPS_ACCURACY_THRESHOLD_M   = 25      // Tolak lokasi jika akurasi > 25m
MIN_MOVEMENT_SPEED_MS      = 0.5     // Batas kecepatan minimum (m/s) sebelum auto-pause
AUTO_PAUSE_THRESHOLD_MS    = 60_000  // Auto-pause setelah 60 detik tidak bergerak

OFF_ROUTE_THRESHOLD_WALK_M = 40      // Toleransi off-route untuk jalan (meter)
OFF_ROUTE_THRESHOLD_JOG_M  = 65      // Toleransi off-route untuk lari (meter)

DEFAULT_WEIGHT_KG          = 70      // Berat default untuk kalkulasi kalori
CALORIE_FACTOR_WALK        = 0.9
CALORIE_FACTOR_JOG         = 1.1

DEFAULT_SPEEDS_KMH = {
  walk_easy: 4,    // Jalan Santai
  walk_fast: 5.5,  // Jalan Cepat
  jog: 8,          // Lari Ringan
}
```

---

## Route Engine (Client-Side OSRM)

> ⚠️ Generate rute **tidak lagi** melalui Supabase Edge Function. Semua logika ada di client.

OSRM endpoint: `https://router.project-osrm.org/route/v1/foot`

### `generateRoutes(lat, lng, targetDistanceM, activityType, isLoop)`

Generate hingga 3 kandidat rute dengan bearing berbeda:
1. Build waypoints di 3 arah (loop: segitiga; one-way: titik tujuan langsung)
2. **Pass 1:** fetch OSRM dengan jarak langkah awal, ukur jarak hasil
3. **Pass 2:** scale waypoints agar jarak ≈ target, fetch ulang
4. Deduplikasi via fingerprint (tolak rute dengan overlap >60%)
5. Sort berdasarkan akurasi jarak ke target
6. Fallback: jika <2 rute berhasil → coba radius ×0.7; jika 0 loop berhasil → coba one-way

Loop routes: koordinat terakhir di-snap ke koordinat pertama untuk memastikan rute tertutup sempurna.

### `generateRouteThroughPoint(startLat, startLng, waypointLat, waypointLng, isLoop, activityType)`

Generate rute melewati waypoint kustom yang dipilih user:
- **One-way:** OSRM langsung dari start ke waypoint (1 kandidat)
- **Loop:** 3 kandidat dengan variasi jalur kembali (langsung, offset 90°, offset 270°)

---

## MapView Component

File: [`src/components/MapView.tsx`](../src/components/MapView.tsx)

```ts
interface Props {
  routeGeoJSON?: GeoJSON.LineString      // Rute rencana — dashed abu-abu (#94A3B8)
  completedGeoJSON?: GeoJSON.LineString  // Track dilalui — solid oranye (#FF5C35)
  children?: React.ReactNode             // ShapeSource tambahan (route-selection)
  followUser?: boolean                   // Camera follow lokasi user
  fitBounds?: FitBounds                  // Zoom ke bounding box
  onPressCoord?: (lat, lng) => void      // Tap peta → koordinat (untuk pilih tujuan)
  markerCoord?: { lat, lng }             // Pin oranye (titik tujuan yang dipilih)
  startMarkerCoord?: { lat, lng }        // Pin hijau (titik start/finish loop)
}
```

**Warna standar:**
- LocationPuck pulsing: `#FF5C35` (oranye)
- Rute rencana: `#94A3B8` dashed
- Track dilalui: `#FF5C35` solid
- Pin tujuan: `#FF5C35` (oranye, 22px)
- Pin start/finish: `#00C46A` (hijau, 30px)

---

## Database Schema (Supabase)

### `activity_sessions` — Riwayat aktivitas yang disimpan
```
id            uuid primary key
user_id       uuid (foreign key ke auth.users)
activity_type text ('walk_easy' | 'walk_fast' | 'jog')
started_at    timestamptz
finished_at   timestamptz
elapsed_distance_m  integer
elapsed_ms    integer
paused_ms     integer
off_route_count     integer
planned_route jsonb (GeoJSON LineString | null)
breadcrumbs   jsonb (GeoJSON LineString | null)
calories      integer
```

Data di-insert langsung via Supabase JS client (bukan Edge Function).

### SQLite Lokal — POI & Avoidance
Tabel `pois` dan `avoidance_zones` di `funroute.db`:
```
id           integer primary key autoincrement
latitude     real
longitude    real
note         text
created_at   text (ISO timestamp)
```

---

## Zustand Stores

### `useAuthStore`
```ts
session: Session | null
user: User | null
isLoading: boolean
signInWithEmail(email, password)
signUpWithEmail(email, password)
signOut()
init()  // panggil sekali di _layout, return unsubscribe fn
```

### `useRouteStore`
```ts
generatedRoutes: RouteCandidate[]
activeRoute: RouteCandidate | null
setGeneratedRoutes(routes)
setActiveRoute(route)
clearRoutes()
```

`RouteCandidate`:
```ts
{
  id: string
  distance_m: number
  estimated_duration_sec: number
  polyline: GeoJSON.LineString
  fingerprint: string
}
```

### `useNavigationStore`
```ts
activityState: 'idle' | 'starting' | 'active' | 'auto_paused' | 'paused' | 'resumed' | 'finished'
currentLocation: LocationObject | null
breadcrumbs: LocationObject[]
elapsedDistanceM: number
pausedMs: number
offRouteCount: number
startMs: number | null
pauseStartMs: number | null

setState(state)
updateLocation(loc, deltaDistanceM)
addPausedTime(ms)
incrementOffRoute()
setStartMs(ms)
setPauseStartMs(ms | null)
reset()
```

### `usePoiStore`
```ts
pois: Poi[]
addPoi(lat, lng, note)
loadPois()
```

### `useAvoidanceStore`
```ts
avoidanceZones: AvoidanceZone[]
addAvoidance(lat, lng, note)
loadAvoidanceZones()
```

---

## LocationService

Singleton class di [`src/services/gps/LocationService.ts`](../src/services/gps/LocationService.ts).

### Mode Tracking

| Method | Akurasi | Interval | Kegunaan |
|--------|---------|----------|---------|
| `startIdleWatching(onLocation)` | Balanced | 10m | Home screen: deteksi posisi awal |
| `startNavigationTracking(callbacks)` | BestForNavigation | 3m | Navigasi aktif |
| `startBackgroundTracking()` | BestForNavigation | 5m | Background via TaskManager |

### Callbacks NavigationTracking
```ts
{
  onLocation(loc, deltaM)    // dipanggil setiap titik valid
  onAutoPause()              // dipanggil saat auto-pause terdeteksi
  onOffRouteCheck(loc)       // dipanggil setiap 3 titik valid
}
```

### Background Queue (SQLite)
- Task: `BACKGROUND_LOCATION_TASK` (didefinisikan di module level, wajib di luar komponen)
- DB: `funroute.db`, tabel `location_queue`
- Drain via `drainLocationQueue()` — ambil 50 baris terlama lalu hapus

---

## Navigasi Antar Screen (Expo Router Params)

### Home → Route Selection
```ts
router.push({
  pathname: '/(app)/route-selection',
  params: {
    lat: string,
    lng: string,
    targetDistanceM: string,
    activityType: string,     // 'walk_easy' | 'walk_fast' | 'jog'
    isLoop: string,           // 'true' | 'false'
    destLat?: string,         // opsional: titik tujuan yang dipilih user
    destLng?: string,
  },
})
```

### Route Selection → Navigation
```ts
router.push({
  pathname: '/(app)/navigation',
  params: {
    routeId: string,
    activityType: string,
    isLoop: string,           // 'true' | 'false' — untuk arrival detection & start pin
  },
})
```

### Navigation → Summary
```ts
router.replace({
  pathname: '/(app)/summary',
  params: {
    activityType: string,
    elapsedDistanceM: string,
    elapsedMs: string,
    pausedMs: string,
    offRouteCount: string,
    calories: string,
    plannedRoute: string,     // JSON GeoJSON LineString
    breadcrumbsJson: string,  // JSON GeoJSON LineString
  },
})
```

> Semua params dari Expo Router datang sebagai `string` — parse ke number/boolean sebelum digunakan.

---

## Pola Kode Wajib

### 1. Auth guard
```ts
// app/(app)/_layout.tsx sudah handle redirect
const { user, session } = useAuthStore()
```

### 2. Akses Supabase (direct insert, bukan Edge Function)
```ts
import { supabase } from '@/services/supabase/client'

const { error } = await supabase.from('activity_sessions').insert({
  user_id: session.user.id,
  activity_type: activityType,
  // ...
})
```

### 3. Generate rute
```ts
import { generateRoutes, generateRouteThroughPoint } from '@/services/routes/RouteGenerator'

// Rute otomatis
const routes = await generateRoutes(lat, lng, targetDistanceM, activityType, isLoop)

// Rute via waypoint kustom
const routes = await generateRouteThroughPoint(startLat, startLng, destLat, destLng, isLoop, activityType)
```

### 4. Analytics
```ts
import { Analytics } from '@/services/analytics/Analytics'
Analytics.track('route_generated', { activityType, targetDistanceM })
```

---

## Environment Variables

```env
EXPO_PUBLIC_SUPABASE_URL=          # URL project Supabase (wajib)
EXPO_PUBLIC_SUPABASE_ANON_KEY=     # Anon/public key Supabase (wajib)
EXPO_PUBLIC_MAPBOX_PUBLIC_TOKEN=   # Mapbox public access token (wajib)
```

---

## Hal yang Perlu Diperhatikan

- `BACKGROUND_LOCATION_TASK` harus didefinisikan di **module level** (luar komponen/hook) — TaskManager requirement dari Expo
- `LocationService.stopTracking()` wajib dipanggil di `useEffect` cleanup
- Route generation **tidak** pakai Supabase Edge Function — murni client OSRM
- Loop polyline: koordinat terakhir selalu di-snap ke koordinat pertama (`closeLoop()` di engine)
- `isLoop` dikirim sebagai string `'true'`/`'false'` via Expo Router params — bandingkan dengan `=== 'true'`
- `expo-sqlite` v16 pakai API async (`openDatabaseAsync`, `runAsync`, `getAllAsync`) — bukan API lama
- Path alias `@/*` → `src/*` sudah dikonfigurasi di `tsconfig.json` dan `babel.config.js`
- Akurasi GPS: lokasi ditolak jika `accuracy > 25m` untuk menghindari noise
