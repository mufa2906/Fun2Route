# FunRoute — API Contract

> Backend: **Supabase** (PostgreSQL + Auth)  
> Route generation: **OSRM public API** (client-side, tanpa auth)  
> ⚠️ Supabase Edge Functions sudah **dihapus** — generate rute dan simpan aktivitas dilakukan langsung dari client.

---

## Auth (Supabase)

Token disimpan otomatis di `expo-secure-store` oleh Supabase JS client.

```ts
const { data: { session } } = await supabase.auth.getSession()
const token = session?.access_token
```

### Sign Up
```ts
supabase.auth.signUp({ email, password })
```

### Sign In
```ts
supabase.auth.signInWithPassword({ email, password })
```

### Sign Out
```ts
supabase.auth.signOut()
```

### Listen Auth State
```ts
supabase.auth.onAuthStateChange((event, session) => { ... })
```

---

## OSRM — Route Generation

> Base URL: `https://router.project-osrm.org/route/v1/foot`  
> Tidak membutuhkan API key atau autentikasi.  
> Semua panggilan OSRM dilakukan dari `src/features/routes/engine/distance-calibrator.ts`.

### `GET /route/v1/foot/{coordinates}`

```
GET https://router.project-osrm.org/route/v1/foot/{lng1},{lat1};{lng2},{lat2};...?overview=full&geometries=geojson
```

**Response**
```json
{
  "code": "Ok",
  "routes": [
    {
      "distance": 3142.5,
      "duration": 2827.0,
      "geometry": {
        "type": "LineString",
        "coordinates": [
          [106.8456, -6.2088],
          [106.8470, -6.2075],
          "..."
        ]
      }
    }
  ]
}
```

**Penggunaan di kode:**
```ts
import { generateRoutes, generateRouteThroughPoint } from '@/services/routes/RouteGenerator'

// Generate rute otomatis (loop atau one-way)
const routes = await generateRoutes(lat, lng, targetDistanceM, activityType, isLoop)

// Generate rute via titik tujuan kustom
const routes = await generateRouteThroughPoint(
  startLat, startLng,
  waypointLat, waypointLng,
  isLoop,
  activityType,
)
```

---

## Supabase Database

Akses langsung ke tabel menggunakan Supabase JS client. Semua tabel dilindungi RLS — user hanya bisa membaca/menulis data miliknya sendiri.

### `INSERT activity_sessions` — Simpan aktivitas selesai

```ts
const { error } = await supabase.from('activity_sessions').insert({
  user_id: session.user.id,
  activity_type: 'walk_easy',            // 'walk_easy' | 'walk_fast' | 'jog'
  started_at: new Date(...).toISOString(),
  finished_at: new Date().toISOString(),
  elapsed_distance_m: 3150,
  elapsed_ms: 2835000,
  paused_ms: 0,
  off_route_count: 2,
  planned_route: { type: 'LineString', coordinates: [...] },  // nullable
  breadcrumbs:   { type: 'LineString', coordinates: [...] },  // nullable
  calories: 212,
})
```

### `SELECT activity_sessions` — Ambil riwayat aktivitas

```ts
const { data, error } = await supabase
  .from('activity_sessions')
  .select('id, activity_type, started_at, elapsed_distance_m, elapsed_ms, calories, off_route_count')
  .order('started_at', { ascending: false })
  .limit(50)
```

**Response row**
```json
{
  "id": "uuid",
  "activity_type": "walk_easy",
  "started_at": "2026-05-12T08:00:00Z",
  "elapsed_distance_m": 3150,
  "elapsed_ms": 2835000,
  "calories": 212,
  "off_route_count": 2
}
```

---

## SQLite Lokal — POI & Avoidance

Data POI dan zona hindari disimpan di device via `expo-sqlite` (`funroute.db`).  
Diakses melalui `usePoiStore` dan `useAvoidanceStore`.

### `pois`
```sql
CREATE TABLE pois (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  note TEXT,
  created_at TEXT
);
```

### `avoidance_zones`
```sql
CREATE TABLE avoidance_zones (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  note TEXT,
  created_at TEXT
);
```

**Penggunaan:**
```ts
const addPoi = usePoiStore((s) => s.addPoi)
const addAvoidance = useAvoidanceStore((s) => s.addAvoidance)

addPoi(latitude, longitude, 'Taman yang bagus')
addAvoidance(latitude, longitude, 'Ramai motor')
```

---

## Navigasi Antar Screen (Expo Router Params)

Params dikirim via `router.push` — bukan HTTP, tapi didokumentasikan di sini sebagai kontrak antar screen.

> Semua params dari Expo Router datang sebagai `string` — parse ke number/boolean sebelum digunakan.

### Home → Route Selection

```ts
router.push({
  pathname: '/(app)/route-selection',
  params: {
    lat: string,              // latitude posisi user
    lng: string,              // longitude posisi user
    targetDistanceM: string,  // target jarak dalam meter
    activityType: string,     // 'walk_easy' | 'walk_fast' | 'jog'
    isLoop: string,           // 'true' | 'false'
    destLat?: string,         // opsional: latitude titik tujuan kustom
    destLng?: string,         // opsional: longitude titik tujuan kustom
  },
})
```

### Route Selection → Navigation

```ts
router.push({
  pathname: '/(app)/navigation',
  params: {
    routeId: string,          // ID RouteCandidate yang dipilih
    activityType: string,
    isLoop: string,           // 'true' | 'false' — untuk start pin & arrival detection
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
    plannedRoute: string,     // JSON.stringify(GeoJSON.LineString) atau ''
    breadcrumbsJson: string,  // JSON.stringify(GeoJSON.LineString) atau ''
  },
})
```
