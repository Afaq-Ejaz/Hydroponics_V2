# 📱 Phase 7: Flutter Client App — Complete Implementation Guide

*Last Updated: 2026-09-16*

> This document is the **single source of truth** for building the HAT Flutter app.
> Every step is self-contained so you can debug, research, or pause at any point
> without losing context.

---

## 📑 Table of Contents

1. [Step 1 — Project Scaffold & Environment ✅](#step-1--project-scaffold--environment)
2. [Step 2 — Authentication (Supabase Auth) ✅](#step-2--authentication-supabase-auth)
3. [Step 3 — Navigation & App Shell ✅](#step-3--navigation--app-shell)
4. [Step 4 — System Selection & Context ✅](#step-4--system-selection--context)
5. [Step 5 — Real-Time Sensor Dashboard ✅](#step-5--real-time-sensor-dashboard)
6. [Step 6 — Device Online/Offline Status ✅](#step-6--device-onlineoffline-status)
7. [Step 7 — Historical Telemetry Charts ✅](#step-7--historical-telemetry-charts)
8. [Step 8 — Alert Management ✅](#step-8--alert-management)
9. [Step 9 — Remote Relay Control & Flow Sensor Clean Architecture ✅](#step-9--remote-relay-control)
10. [Step 10 — Polish, Theming & UX ✅](#step-10--polish-theming--ux)
11. [Appendix A — Complete API Reference](#appendix-a--complete-api-reference)
12. [Appendix B — Database Tables the App Touches](#appendix-b--database-tables-the-app-touches)
13. [Appendix C — Keys & Config Reference](#appendix-c--keys--config-reference)

---

---

## Step 1 — Project Scaffold & Environment ✅

**Goal**: Create the Flutter project, add all dependencies, and verify it runs.
**Status**: **COMPLETED** (Verified with `flutter analyze` 0 issues and debug APK build)

### 1.1 — Create the Flutter Project

```bash
cd c:\HAT
flutter create client
cd client
```

This creates `c:\HAT\client\` with the standard Flutter project structure.

**Verify**: Run `flutter run -d chrome` (web) or `flutter run` (connected device). You should see the default Flutter counter app.

### 1.2 — Add Dependencies

Open `client/pubspec.yaml` and add these dependencies:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # ── Supabase (Auth + Realtime + DB) ──
  supabase_flutter: ^2.8.0        # All-in-one Supabase SDK

  # ── State Management ──
  flutter_riverpod: ^2.6.1        # Reactive state management

  # ── Charts ──
  fl_chart: ^0.70.2               # Line charts for telemetry history

  # ── HTTP ──
  http: ^1.2.2                    # REST calls to FastAPI backend

  # ── UI Helpers ──
  google_fonts: ^6.2.1            # Premium typography
  flutter_animate: ^4.5.0         # Micro-animations (optional but recommended)
  intl: ^0.19.0                   # Date/time formatting

  # ── Auth (only if you choose Google Sign-In — see Step 2) ──
  # google_sign_in: ^6.2.2        # Uncomment if using Google OAuth
```

Then run:

```bash
cd c:\HAT\client
flutter pub get
```

**Verify**: `flutter pub get` completes with no errors.

### 1.3 — Create the Environment Config File

Create `client/lib/config.dart`:

```dart
class AppConfig {
  // ── Supabase ──
  static const String supabaseUrl = 'https://vijkujtwbotqcnoviodd.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZpamt1anR3Ym90cWNub3Zpb2RkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3NzQxMDIsImV4cCI6MjEwNDM1MDEwMn0.QEgIkflqqrx6rxe-jwZ88de458TyoJD3FmA8aj1ND34'; // NOT service_role!

  // ── FastAPI Backend ──
  static const String backendBaseUrl = 'http://10.9.26.152:8000';
}
```

> ⚠️ **IMPORTANT**: The Flutter app must use the **anon key** (public), NOT the
> service_role key. The anon key respects RLS policies. You can find it in
> Supabase Dashboard → Settings → API → `anon` `public` key.

**Verify**: File exists, no syntax errors. App still builds.

### 1.4 — Initialize Supabase in `main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(const HATApp());
}

// Quick access helper used throughout the app
final supabase = Supabase.instance.client;
```

**Verify**: App launches without crash. Check debug console for "Supabase initialized" or no errors.

### 1.5 — Scaffold Summary Checklist

| Task | Status |
|:---|:---|
| Flutter project created (`c:\HAT\client\`) | ☑ Completed |
| Dependencies added to `pubspec.yaml` & `flutter pub get` passed | ☑ Completed |
| Environment config file created (`client/lib/core/config/app_config.dart`) | ☑ Completed |
| Supabase initialized in `main.dart` with Riverpod `ProviderScope` | ☑ Completed |
| Android `minSdk = 21` configured for Supabase compatibility | ☑ Completed |
| Verified zero lint warnings (`flutter analyze` 0 issues) & debug APK builds | ☑ Completed |

---

---

## Step 2 — Authentication (Supabase Auth) ✅

**Goal**: Let users sign in, sign up, and sign out. Their profile auto-syncs to the `profiles` table.
**Status**: **COMPLETED** (Email + Password implemented; Google Auth skipped per user specification)

### 2.0 — Which Auth Method Should You Use?

Supabase supports multiple auth strategies. Here's the honest comparison for YOUR project:

| Method | Setup Complexity | User Experience | Best For |
|:---|:---|:---|:---|
| **Email + Password** | 🟢 Easiest (works out of box) | User types email + password | ✅ **Recommended for you** — simplest, no external config needed |
| **Google Sign-In** | 🟡 Medium (needs Google Cloud Console setup) | One-tap sign in with Google account | Good UX, but requires OAuth client ID setup |
| **Magic Link (Email OTP)** | 🟢 Easy | User gets a login link via email, no password | Great UX, but needs email delivery configured |
| **Phone OTP (SMS)** | 🔴 Complex (needs Twilio or similar) | User gets SMS code | Overkill for this project |
| **GitHub / Apple / Facebook** | 🟡 Medium each | Social login buttons | Not relevant for a hydroponics IoT app |

#### My Recommendation

**Start with Email + Password (2.1)**. It works immediately with zero external config. You can always ADD Google Sign-In (2.2) later as an additional option — Supabase supports multiple providers simultaneously.

---

### 2.1 — Email + Password Authentication

This is the simplest path. Supabase handles everything — password hashing, JWT tokens, session management, and the `profiles` trigger you already have in your database.

#### 2.1.1 — Enable Email Auth in Supabase Dashboard

1. Go to **Supabase Dashboard** → **Authentication** → **Providers**.
2. Ensure **Email** is enabled (it is by default).
3. Optional: Under **Authentication** → **Settings**, toggle **"Confirm email"** OFF for development (so you don't need to check inbox every time you test). Turn it back ON for production.

**Verify**: The toggle is ON in the dashboard.

#### 2.1.2 — Build the Sign-Up Screen

Create `client/lib/screens/auth/signup_screen.dart`:

**Core logic** (what matters for debugging):

```dart
// Sign up a new user
final response = await supabase.auth.signUp(
  email: emailController.text.trim(),
  password: passwordController.text,
  data: {'full_name': nameController.text.trim()},  // goes into raw_user_meta_data
);

// Check for errors
if (response.user == null) {
  // Show error: "Sign up failed"
}
// If email confirmation is ON, user gets an email
// If email confirmation is OFF, user is immediately signed in
```

**What happens in the database when a user signs up**:
1. Supabase creates a row in `auth.users`.
2. Your existing trigger (`on_auth_user_created`) fires automatically.
3. The trigger inserts a row into `public.profiles` with `id`, `email`, `full_name`.
4. The user is now in your system.

**Things that can go wrong (debug checklist)**:
- ❌ "User already registered" → Email already exists in `auth.users`.
- ❌ "Password should be at least 6 characters" → Supabase default minimum.
- ❌ Profile row not created → Check that the `handle_new_user()` trigger exists in your database.
- ❌ Network error → Check Supabase URL and anon key in `config.dart`.

**Verify**: Sign up with a test email. Check Supabase Dashboard → Authentication → Users. Check `profiles` table for the new row.

#### 2.1.3 — Build the Login Screen

Create `client/lib/screens/auth/login_screen.dart`:

**Core logic**:

```dart
final response = await supabase.auth.signInWithPassword(
  email: emailController.text.trim(),
  password: passwordController.text,
);

if (response.session == null) {
  // Show error: "Invalid credentials"
}
// On success, supabase.auth.currentSession is now set
// supabase.auth.currentUser gives you the user object
```

**Things that can go wrong**:
- ❌ "Invalid login credentials" → Wrong email or password.
- ❌ "Email not confirmed" → User signed up but hasn't confirmed email. Either confirm in dashboard or disable confirmation for dev.
- ❌ Session is null → Double-check anon key.

**Verify**: Log in with the test user. `supabase.auth.currentUser` is non-null.

#### 2.1.4 — Build the Sign-Out Logic

```dart
await supabase.auth.signOut();
// Navigate back to login screen
```

**Verify**: After sign out, `supabase.auth.currentSession` is null.

#### 2.1.5 — Auth State Listener (Auto-redirect)

In your app's root widget, listen for auth state changes to auto-navigate:

```dart
supabase.auth.onAuthStateChange.listen((data) {
  final event = data.event;
  if (event == AuthChangeEvent.signedIn) {
    // Navigate to Dashboard
  } else if (event == AuthChangeEvent.signedOut) {
    // Navigate to Login
  }
});
```

**This is important because**:
- If the user closes the app and reopens it, Supabase auto-restores the session from secure storage.
- The listener fires `signedIn` automatically if a valid session exists.

**Verify**: Sign in → force close app → reopen → you should land on Dashboard (not Login).

---

### 2.2 — Google Sign-In (Optional Add-On)

Only follow this if you want a "Sign in with Google" button IN ADDITION to email/password.

#### 2.2.1 — Google Cloud Console Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/).
2. Create a new project (or use existing).
3. Go to **APIs & Services** → **OAuth consent screen** → Configure.
4. Go to **APIs & Services** → **Credentials** → **Create Credentials** → **OAuth 2.0 Client ID**.
5. For **Android**: Select "Android", provide your app's package name and SHA-1 fingerprint.
   ```bash
   cd c:\HAT\client\android
   ./gradlew signingReport
   # Copy the SHA-1 from the debug variant
   ```
6. For **Web**: Select "Web application", add `https://vijkujtwbotqcnoviodd.supabase.co/auth/v1/callback` as an authorized redirect URI.
7. Copy the **Client ID** and **Client Secret**.

#### 2.2.2 — Configure Google Provider in Supabase

1. Supabase Dashboard → **Authentication** → **Providers** → **Google**.
2. Toggle ON.
3. Paste the **Client ID** and **Client Secret** from step 2.2.1.
4. Save.

#### 2.2.3 — Flutter Implementation

Add the dependency (uncomment in `pubspec.yaml`):

```yaml
google_sign_in: ^6.2.2
```

**Core logic**:

```dart
import 'package:google_sign_in/google_sign_in.dart';

Future<void> signInWithGoogle() async {
  // 1. Trigger Google Sign-In flow
  final googleUser = await GoogleSignIn(
    clientId: '<YOUR_WEB_CLIENT_ID>',  // from Google Cloud Console
  ).signIn();

  if (googleUser == null) return; // User cancelled

  // 2. Get the ID token
  final googleAuth = await googleUser.authentication;
  final idToken = googleAuth.idToken;
  final accessToken = googleAuth.accessToken;

  if (idToken == null) throw 'No ID token';

  // 3. Sign in to Supabase with the Google token
  await supabase.auth.signInWithIdToken(
    provider: OAuthProvider.google,
    idToken: idToken,
    accessToken: accessToken,
  );
}
```

**Things that can go wrong**:
- ❌ "redirect_uri_mismatch" → The redirect URI in Google Console doesn't match Supabase's callback URL.
- ❌ "PlatformException" on Android → SHA-1 fingerprint doesn't match, or package name is wrong.
- ❌ Profile not created → The `handle_new_user()` trigger still fires, but check that `raw_user_meta_data->>'full_name'` exists in the Google user data.

**Verify**: Tap "Sign in with Google" → Google picker appears → after selecting account, user appears in Supabase Dashboard → Users AND in `profiles` table.

---

### 2.3 — Auth Summary Checklist

| Task | Status |
|:---|:---|
| Supabase Email provider enabled | ☑ Completed |
| Sign-Up screen built & tested (`client/lib/features/auth/screens/signup_screen.dart`) | ☑ Completed |
| Login screen built & tested (`client/lib/features/auth/screens/login_screen.dart`) | ☑ Completed |
| Sign-Out working (`client/lib/features/settings/screens/settings_screen.dart`) | ☑ Completed |
| Auth state listener auto-redirects (`client/lib/core/router/app_router.dart`) | ☑ Completed |
| Session persists across app restarts (Supabase secure local storage) | ☑ Completed |
| (Optional) Google Sign-In configured | ⊘ Skipped (Email/Password selected per requirement) |

---

---

## Step 3 — Navigation & App Shell ✅

**Goal**: Set up the app's navigation skeleton — a bottom nav bar with the main screens.
**Status**: **COMPLETED** (Built with GoRouter ShellRoute and 5 tabs matching Figma)

### 3.1 — Define the Screen Structure

The app needs these top-level screens:

| Tab | Icon | Screen | Purpose |
|:---|:---|:---|:---|
| 🏠 Dashboard | `Icons.dashboard` | `DashboardScreen` | Live sensor gauges + device status |
| 📈 Charts | `Icons.show_chart` | `ChartsScreen` | Historical telemetry line plots |
| 🚨 Alerts | `Icons.notifications` | `AlertsScreen` | Alert list + acknowledge actions |
| ⚙️ Settings | `Icons.settings` | `SettingsScreen` | Profile, system info, sign out |

### 3.2 — Build the App Shell

Create `client/lib/screens/app_shell.dart`:

- Use a `Scaffold` with a `BottomNavigationBar` (or `NavigationBar` for Material 3).
- Use an `IndexedStack` or `PageView` to keep screen state alive when switching tabs.
- The Alerts tab should show an **unread badge** (count of unacknowledged alerts).

**Verify**: You can tap between all 4 tabs. Each shows a placeholder text. No crashes.

### 3.3 — Route Guard (Protect Screens)

Wrap the app shell so unauthenticated users always see the Login screen:

```dart
// In your app's router/builder:
final session = supabase.auth.currentSession;
if (session == null) {
  return const LoginScreen();
} else {
  return const AppShell();
}
```

**Verify**: When signed out → Login screen. When signed in → AppShell with tabs.

### 3.4 — Navigation Summary Checklist

| Task | Status |
|:---|:---|
| 5-tab screen structure defined (Dashboard, Charts, History, Alerts, Settings) | ☑ Completed |
| Material 3 bottom `NavigationBar` with `ShellRoute` (`_AppShell`) | ☑ Completed |
| Tab state preservation and smooth route navigation via GoRouter | ☑ Completed |
| Route Guard protecting screens from unauthenticated access | ☑ Completed |
| Placeholder / functional screens created for all 5 tabs | ☑ Completed |

---

---

## Step 4 — System Selection & Context ✅

**Goal**: After login, determine WHICH hydroponic system the user belongs to and store it as the active context.
**Status**: **COMPLETED** (SystemContextGate auto-selects system + loads devices; no-system fallback screen included)

### 4.1 — Why This Step Matters

Your database is **multi-tenant**. A user can belong to multiple hydroponic systems (via `system_members`). Every API call needs a `system_id`. The app must know which system is active.

### 4.2 — Fetch the User's Systems

After login, query the user's systems:

```dart
final userId = supabase.auth.currentUser!.id;

final response = await supabase
    .from('system_members')
    .select('system_id, role, hydroponic_systems(id, name, description)')
    .eq('user_id', userId);

// response.data = [
//   {
//     "system_id": "uuid-...",
//     "role": "owner",
//     "hydroponic_systems": { "id": "uuid-...", "name": "My Farm", ... }
//   }
// ]
```

**Things that can go wrong**:
- ❌ Empty list → User exists in `profiles` but has no `system_members` entry. You need to manually insert one in the database, or build a "Create System" flow.
- ❌ RLS error → Make sure the `system_members` RLS policy allows users to SELECT their own memberships.

### 4.3 — Store Active System in State

Use Riverpod (or any state management) to store the active system:

```dart
// A simple StateProvider
final activeSystemProvider = StateProvider<String?>((ref) => null);

// After fetching systems:
ref.read(activeSystemProvider.notifier).state = systems.first['system_id'];
```

### 4.4 — Fetch Devices for the Active System

Once you have the `system_id`, fetch its devices:

```dart
final devices = await supabase
    .from('devices')
    .select('*')
    .eq('system_id', activeSystemId);

// devices.data = [
//   { "id": "ESP32_01", "name": "Main Controller", "is_active": true, ... }
// ]
```

**Verify**: After login, print the system name and device list to the debug console. You should see your actual data.

### 4.5 — System Selection Checklist

| Task | Status |
|:---|:---|
| Fetch user's systems from `system_members` | ☑ Completed (`system_provider.dart` → `userSystemsProvider`) |
| Store active `system_id` in state | ☑ Completed (`ActiveSystemNotifier` + `activeSystemIdProvider`) |
| Fetch devices for active system | ☑ Completed (`systemDevicesProvider` + `primaryDeviceProvider`) |
| Handle edge case: user has 0 systems | ☑ Completed (redirects to `NoSystemScreen`) |
| Handle edge case: user has multiple systems (show picker) | ☑ Auto-selects first system (picker can be added later) |

---

---

## Step 5 — Real-Time Sensor Dashboard ✅

**Goal**: Show LIVE sensor values updating in real-time as the ESP32 sends data every 30 seconds.
**Status**: **COMPLETED** (Supabase Realtime stream → SensorCard grid with `*` footnote for disconnected probes)

### 5.1 — How Real-Time Works in Your System

```
ESP32 → POST /ingest → FastAPI → INSERT into sensor_readings → Supabase Realtime → Flutter app
```

Your database already has realtime enabled:
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE public.sensor_readings;
```

So every INSERT into `sensor_readings` is automatically broadcast to all subscribed clients.

### 5.2 — Subscribe to Real-Time Sensor Updates

```dart
final channel = supabase
    .from('sensor_readings')
    .stream(primaryKey: ['id'])
    .eq('system_id', activeSystemId)
    .order('recorded_at', ascending: false)
    .limit(1);

// This returns a Stream<List<Map<String, dynamic>>>
// Every time a new reading is inserted, this stream emits
```

Use this in a `StreamBuilder` widget:

```dart
StreamBuilder<List<Map<String, dynamic>>>(
  stream: channel,
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const CircularProgressIndicator();

    final latest = snapshot.data!.first;
    final ec = latest['ec'];
    final moisture = latest['moisture'];
    final airTemp = latest['air_temperature'];
    final humidity = latest['humidity'];
    final waterLevel = latest['water_level'];

    return DashboardGrid(
      ec: ec,
      moisture: moisture,
      airTemp: airTemp,
      humidity: humidity,
      waterLevel: waterLevel,
    );
  },
);
```

**Things that can go wrong**:
- ❌ Stream never emits → Check that `supabase_realtime` publication includes `sensor_readings`. Check that your `system_id` filter matches actual data.
- ❌ RLS blocks the stream → The anon key user must have a `system_members` row linking them to the system. The RLS policy `has_system_access()` must return true.
- ❌ "Permission denied" → You're using the service_role key instead of anon key (service_role bypasses RLS but shouldn't be in the client).

### 5.3 — Build Sensor Gauge Cards

Build individual gauge/card widgets for each sensor. These are the **5 active sensors**:

| Sensor | Field Name | Unit | Typical Range | Card Color Suggestion |
|:---|:---|:---|:---|:---|
| EC (Nutrients) | `ec` | mS/cm | 0.5 – 3.0 | Green/Teal |
| Moisture | `moisture` | % | 0 – 100 | Blue |
| Air Temperature | `air_temperature` | °C | 18 – 35 | Orange/Red |
| Humidity | `humidity` | % | 30 – 90 | Cyan |
| Water Level | `water_level` | cm | 5 – 40 | Purple |

Each card should show:
- **Current value** (large number)
- **Unit label**
- **Sensor name**
- **Last updated timestamp**
- Optional: color-coded ring or progress indicator

### 5.4 — Handle Missing/NaN Sensor Values

The ESP32 can send `null` for any sensor if the probe fails. Your card should show a fallback:

```dart
Text(ec != null ? ec.toStringAsFixed(2) : '--', style: ...);
```

### 5.5 — Dashboard Checklist

| Task | Status |
|:---|:---|
| Realtime stream subscription working | ☑ Completed (`sensorStreamProvider` via Supabase `.stream()`) |
| EC gauge card displays live value | ☑ Completed (via `SensorCard` + `SensorMeta`) |
| Moisture gauge card displays live value | ☑ Completed |
| Air Temperature card displays live value | ☑ Completed |
| Humidity card displays live value | ☑ Completed |
| Water Level card displays live value | ☑ Completed |
| Null/missing values handled gracefully | ☑ Completed (`-- *` footnote for disconnected sensors) |
| Values update every ~30 seconds (matching ESP32 interval) | ☑ Completed (Supabase Realtime push) |

---

---

## Step 6 — Device Online/Offline Status ✅

**Goal**: Show a prominent badge indicating whether the ESP32 is currently ONLINE or OFFLINE.
**Status**: **COMPLETED** (DeviceStatusBadge polls `GET /devices/{id}/status` every 60s + SystemStatusBanner)

### 6.1 — Use the Backend Status Endpoint

Your backend already has this endpoint built and tested:

```
GET /devices/{device_id}/status
```

**Response**:
```json
{
  "device_id": "ESP32_01",
  "system_id": "uuid-...",
  "name": "Main Controller",
  "is_active": true,
  "status": "online",          // or "offline"
  "last_seen": "2026-09-16T15:30:00Z",
  "minutes_since_last_seen": 1.5
}
```

The backend considers a device **offline** if `last_seen` is older than 5 minutes (configurable via `DEVICE_OFFLINE_THRESHOLD_MINUTES`).

### 6.2 — Flutter Implementation

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

Future<Map<String, dynamic>> fetchDeviceStatus(String deviceId) async {
  final url = Uri.parse('${AppConfig.backendBaseUrl}/devices/$deviceId/status');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to fetch device status: ${response.statusCode}');
  }
}
```

### 6.3 — Poll vs. Realtime for Status

**Option A (Simple — Recommended to start)**: Poll every 60 seconds using a `Timer.periodic`:

```dart
Timer.periodic(const Duration(seconds: 60), (_) {
  fetchDeviceStatus('ESP32_01');
});
```

**Option B (Advanced)**: Derive status from the realtime `sensor_readings` stream. If the last reading is older than 5 minutes, show OFFLINE. This avoids an extra HTTP call.

### 6.4 — Status Badge UI

```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: isOnline ? Colors.green.shade900 : Colors.red.shade900,
    borderRadius: BorderRadius.circular(20),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        isOnline ? Icons.wifi : Icons.wifi_off,
        color: Colors.white,
        size: 16,
      ),
      SizedBox(width: 6),
      Text(
        isOnline ? 'ONLINE' : 'OFFLINE',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    ],
  ),
);
```

### 6.5 — Status Checklist

| Task | Status |
|:---|:---|
| `/devices/{id}/status` endpoint called from Flutter | ☑ Completed (`device_status_provider.dart`) |
| Online badge (green) displays correctly | ☑ Completed (`DeviceStatusBadge` widget) |
| Offline badge (red) displays correctly | ☑ Completed |
| Status refreshes periodically | ☑ Completed (60s `Timer.periodic` in provider) |
| "Last seen X minutes ago" text shown | ☑ Completed (in `SystemStatusBanner` offline state) |

---

---

## Step 7 — Historical Telemetry Charts

**Goal**: Show smooth line charts of sensor data over time (last 24h, 7 days, 30 days).

### 7.1 — Use the Backend Telemetry Endpoint

```
GET /systems/{system_id}/telemetry/hourly?limit=24
```

**Response** (array of hourly buckets):
```json
[
  {
    "system_id": "uuid-...",
    "device_id": "ESP32_01",
    "bucket": "2026-09-16T14:00:00Z",
    "avg_ph": null,
    "avg_ec": 1.45,
    "avg_water_temp": null,
    "avg_water_level": 22.10,
    "avg_air_temp": 24.50,
    "avg_humidity": 65.30,
    "avg_light_intensity": null,
    "avg_moisture": 58.20,
    "avg_flow_rate": null,
    "sample_count": 120
  },
  ...
]
```

### 7.2 — Fetch Chart Data

```dart
Future<List<Map<String, dynamic>>> fetchHourlyTelemetry(
  String systemId, {
  int limit = 24,
}) async {
  final url = Uri.parse(
    '${AppConfig.backendBaseUrl}/systems/$systemId/telemetry/hourly?limit=$limit',
  );
  final response = await http.get(url);

  if (response.statusCode == 200) {
    return List<Map<String, dynamic>>.from(jsonDecode(response.body));
  } else {
    throw Exception('Failed to fetch telemetry: ${response.statusCode}');
  }
}
```

### 7.3 — Time Range Selector

Add a segmented button / toggle for the user to pick:

| Label | `limit` value | What it shows |
|:---|:---|:---|
| Last 24 Hours | `24` | 24 hourly buckets |
| Last 7 Days | `168` | 168 hourly buckets (7 × 24) |
| Last 30 Days | `720` | 720 hourly buckets (30 × 24) |

### 7.4 — Build Line Charts with `fl_chart`

```dart
import 'package:fl_chart/fl_chart.dart';

LineChartData buildChart(List<Map<String, dynamic>> data, String field) {
  final spots = data.reversed.toList().asMap().entries.map((entry) {
    final value = entry.value[field] as num?;
    return FlSpot(entry.key.toDouble(), value?.toDouble() ?? 0);
  }).toList();

  return LineChartData(
    lineBarsData: [
      LineChartBarData(
        spots: spots,
        isCurved: true,
        color: Colors.tealAccent,
        barWidth: 2,
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: Colors.tealAccent.withOpacity(0.15),
        ),
      ),
    ],
    // ... configure axes, grid, tooltips
  );
}
```

### 7.5 — Which Fields to Chart

| Chart Title | Data Field | Unit |
|:---|:---|:---|
| EC (Nutrients) | `avg_ec` | mS/cm |
| Moisture | `avg_moisture` | % |
| Air Temperature | `avg_air_temp` | °C |
| Humidity | `avg_humidity` | % |
| Water Level | `avg_water_level` | cm |

> **Note**: `avg_ph`, `avg_water_temp`, `avg_light_intensity`, and `avg_flow_rate` will be `null`
> for now because those sensors are excluded from the ESP32 firmware. The charts should
> gracefully handle null data (show "No data" or skip those charts).

### 7.6 — Charts Checklist

| Task | Status |
|:---|:---|
| Telemetry endpoint called from Flutter | ☑ Completed (`hourlyTelemetryProvider` via FastAPI `/telemetry/hourly`) |
| Time range selector (24h / 7d / 30d) works | ☑ Completed (`chartTimeRangeProvider` with segmented bar) |
| EC line chart renders | ☑ Completed (Nutrient Balance chart with target ranges) |
| Moisture line chart renders | ☑ Completed (Climate Monitoring chart) |
| Air Temperature line chart renders | ☑ Completed (Thermal Dynamics chart) |
| Humidity line chart renders | ☑ Completed (Climate Monitoring chart) |
| Water Level line chart renders | ☑ Completed (Reservoir & Flow chart) |
| Flow Rate line chart renders | ☑ Completed (Modular & pluggable with `sensorFlow` token) |
| Null fields handled (no crash) | ☑ Completed (Graceful offline probe state displayed) |
| Charts scroll or paginate nicely | ☑ Completed (Categorized filter chips matching Figma UI) |

---

---

## Step 8 — Alert Management

**Goal**: Display all system alerts, show unread count, and let users acknowledge them.

### 8.1 — How Alerts Are Generated (Context)

Alerts come from TWO sources (both already built in the backend):

1. **Threshold Alerts** (from `alert_service.py`):
   - pH too low (`< 5.5`) → `critical`
   - pH too high (`> 6.5`) → `critical`
   - Water temp too high (`> 26°C`) → `warning`
   - Water temp too low (`< 16°C`) → `warning`

2. **Offline Alerts** (from `watchdog_service.py`):
   - Device stops sending data for > 5 minutes → `critical`

### 8.2 — Fetch Alerts

```
GET /alerts?system_id={system_id}&is_acknowledged=false&limit=50
```

**Response**:
```json
{
  "alerts": [
    {
      "id": "uuid-...",
      "system_id": "uuid-...",
      "device_id": "ESP32_01",
      "severity": "critical",
      "message": "Device 'Main Controller' (ESP32_01) has stopped reporting. Last seen: 2026-09-16T15:00:00Z.",
      "is_acknowledged": false,
      "acknowledged_by": null,
      "acknowledged_at": null,
      "created_at": "2026-09-16T15:05:00Z"
    }
  ],
  "total_count": 3
}
```

**Flutter implementation**:

```dart
Future<Map<String, dynamic>> fetchAlerts(
  String systemId, {
  bool? isAcknowledged,
  String? severity,
  int limit = 50,
}) async {
  final params = {
    'system_id': systemId,
    'limit': limit.toString(),
    if (isAcknowledged != null) 'is_acknowledged': isAcknowledged.toString(),
    if (severity != null) 'severity': severity,
  };

  final url = Uri.parse('${AppConfig.backendBaseUrl}/alerts')
      .replace(queryParameters: params);
  final response = await http.get(url);

  return jsonDecode(response.body);
}
```

### 8.3 — Acknowledge an Alert

```
PATCH /alerts/{alert_id}/acknowledge
```

**Body** (optional):
```json
{
  "acknowledged_by": "user-uuid-..."
}
```

**Flutter implementation**:

```dart
Future<void> acknowledgeAlert(String alertId) async {
  final url = Uri.parse('${AppConfig.backendBaseUrl}/alerts/$alertId/acknowledge');
  final userId = supabase.auth.currentUser?.id;

  await http.patch(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      if (userId != null) 'acknowledged_by': userId,
    }),
  );
}
```

### 8.4 — Real-Time Alert Push

Your database already publishes `alerts` to Supabase Realtime:
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE public.alerts;
```

Subscribe to live alert notifications:

```dart
supabase
    .from('alerts')
    .stream(primaryKey: ['id'])
    .eq('system_id', activeSystemId)
    .eq('is_acknowledged', false)
    .order('created_at', ascending: false)
    .listen((alerts) {
      // Update alert count badge on the bottom nav
      // Show a snackbar/toast for new critical alerts
    });
```

### 8.5 — Alert List UI

Build an alert card with:
- **Severity icon**: 🔴 `critical` / 🟡 `warning` / 🔵 `info`
- **Message text**
- **Timestamp** (use `intl` package: `DateFormat.yMd().add_jm().format(...)`)
- **"Acknowledge" button** (only for unacknowledged alerts)
- **Filter tabs**: All / Unacknowledged / Critical / Warning

### 8.6 — Alert Badge on Bottom Nav

Show the count of unacknowledged alerts on the Alerts tab icon:

```dart
NavigationDestination(
  icon: Badge(
    label: Text(unreadCount.toString()),
    isLabelVisible: unreadCount > 0,
    child: const Icon(Icons.notifications_outlined),
  ),
  selectedIcon: Badge(
    label: Text(unreadCount.toString()),
    isLabelVisible: unreadCount > 0,
    child: const Icon(Icons.notifications),
  ),
  label: 'Alerts',
),
```

### 8.7 — Alerts Checklist

| Task | Status |
|:---|:---|
| `GET /alerts` called from Flutter | ☑ Completed (`alertsProvider` via backend `/alerts`) |
| Alert list displays with severity icons | ☑ Completed (`AlertCard` with 🔴 critical, 🟡 warning, 🔵 info) |
| Filter by acknowledged/unacknowledged works | ☑ Completed (`AlertFilter`: All, Active, Critical, Warning) |
| Filter by severity works | ☑ Completed |
| "Acknowledge" button calls PATCH endpoint | ☑ Completed (`PATCH /alerts/{id}/acknowledge`) |
| Acknowledged alert disappears from unread list | ☑ Completed (Optimistic update with real-time sync) |
| Realtime alert subscription works | ☑ Completed (Supabase Realtime `.stream()` on `alerts`) |
| Badge count on bottom nav updates | ☑ Completed (`unreadAlertsCountProvider` on shell NavigationBar) |
| Dashboard header badge count & navigation | ☑ Completed (AppBar bell badge navigates to `/alerts`) |

---

---

## Step 9 — Remote Relay Control

**Goal**: Let the user toggle the ESP32 relay (pump/light) ON or OFF from the app.

### 9.1 — How This Works (Architecture Decision)

This is the ONE feature that needs **new backend work**. The current system is one-directional (ESP32 → Backend). For relay control, we need Backend → ESP32.

**Two approaches**:

| Approach | How It Works | Complexity | Latency |
|:---|:---|:---|:---|
| **A: ESP32 Polls Backend** | ESP32 calls `GET /devices/{id}/relay-state` every 5–10 seconds. Backend stores desired state in DB. App writes desired state via `PUT`. | 🟢 Simple | 5–10 sec |
| **B: MQTT Pub/Sub** | ESP32 subscribes to an MQTT topic. Backend publishes relay commands. Near-instant. | 🟡 Medium (needs MQTT broker) | < 1 sec |

**Recommendation**: Start with **Approach A** (polling). It's simpler and uses your existing HTTP infrastructure. You can upgrade to MQTT later if the latency matters.

### 9.2 — Database Changes (New Migration)

Create a new migration to store relay state:

```sql
-- Migration: Add relay_state column to devices
ALTER TABLE public.devices
    ADD COLUMN IF NOT EXISTS relay_state BOOLEAN NOT NULL DEFAULT false;
```

### 9.3 — Backend Changes (New Endpoints)

Add TWO new endpoints to `backend/src/main.py`:

**GET** — ESP32 reads desired state:
```python
@app.get("/devices/{device_id}/relay-state")
async def get_relay_state(device_id: str, db: Client = Depends(get_db)):
    response = db.table("devices").select("relay_state").eq("id", device_id).execute()
    if not response.data:
        raise HTTPException(status_code=404, detail="Device not found")
    return {"device_id": device_id, "relay_on": response.data[0]["relay_state"]}
```

**PUT** — Flutter app sets desired state:
```python
@app.put("/devices/{device_id}/relay-state")
async def set_relay_state(device_id: str, body: dict, db: Client = Depends(get_db)):
    relay_on = body.get("relay_on", False)
    db.table("devices").update({"relay_state": relay_on}).eq("id", device_id).execute()
    return {"device_id": device_id, "relay_on": relay_on}
```

### 9.4 — Firmware Changes (ESP32 Polls)

Add to `firmware/src/main.cpp` in the `loop()` function:

```cpp
// After sending sensor data, check relay state
if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(String(BACKEND_URL_BASE) + "/devices/" + DEVICE_ID + "/relay-state");
    int code = http.GET();
    if (code == 200) {
        String body = http.getString();
        // Parse JSON: {"relay_on": true/false}
        JsonDocument doc;
        deserializeJson(doc, body);
        bool relayOn = doc["relay_on"] | false;
        digitalWrite(PIN_RELAY, relayOn ? HIGH : LOW);
        Serial.printf("[Relay] State: %s\n", relayOn ? "ON" : "OFF");
    }
    http.end();
}
```

### 9.5 — Flutter Toggle Switch

```dart
Switch(
  value: relayIsOn,
  onChanged: (bool newValue) async {
    final url = Uri.parse(
      '${AppConfig.backendBaseUrl}/devices/$deviceId/relay-state',
    );
    await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'relay_on': newValue}),
    );
    setState(() => relayIsOn = newValue);
  },
);
```

### 9.6 — Relay Control & Clean Flow Sensor Checklist

| Task | Status |
|:---|:---|
| `relay_state` column handling in backend | ☑ Completed (`GET` & `PUT /devices/{id}/relay-state` with DB & memory fallback) |
| `GET /devices/{id}/relay-state` endpoint built | ☑ Completed in `backend/src/main.py` |
| `PUT /devices/{id}/relay-state` endpoint built | ☑ Completed in `backend/src/main.py` |
| Flow sensor registered in metadata & models | ☑ Completed (`SensorMeta`, `SensorReading`, `HourlyTelemetry`) |
| Zero-clutter flow sensor readiness | ☑ Completed (Automatically displays live data when connected today) |
| Flutter toggle switch calls PUT endpoint | ☑ Completed (`relay_provider.dart` + `RelayControlCard`) |
| UI shows current relay state & standby mode | ☑ Completed (Embedded on dashboard) |

---

---

## Step 10 — Polish, Theming & UX 🟡 (Foundations Complete)

**Goal**: Make the app look and feel premium.
**Status**: **PARTIALLY COMPLETED** (Design system tokens, Figma light theme, Inter font, animations, and loading overlays implemented)

### 10.1 — Dark Theme Setup

```dart
MaterialApp(
  theme: ThemeData.dark().copyWith(
    colorScheme: ColorScheme.dark(
      primary: Color(0xFF00E5A0),    // Teal/green accent
      secondary: Color(0xFF00B4D8),  // Cyan accent
      surface: Color(0xFF1A1A2E),    // Dark card background
      background: Color(0xFF0F0F1A), // Deepest background
    ),
    scaffoldBackgroundColor: Color(0xFF0F0F1A),
    cardTheme: CardTheme(
      color: Color(0xFF1A1A2E),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
);
```

### 10.2 — Typography

```dart
import 'package:google_fonts/google_fonts.dart';

// Use in theme:
textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
```

### 10.3 — Glassmorphism Cards (Optional)

For the sensor gauge cards, use a frosted glass effect:

```dart
ClipRRect(
  borderRadius: BorderRadius.circular(16),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: // ... your card content
    ),
  ),
);
```

### 10.4 — Animations

Use `flutter_animate` for subtle entry animations:

```dart
import 'package:flutter_animate/flutter_animate.dart';

// Make cards fade + slide in on load:
SensorCard(value: ec)
    .animate()
    .fadeIn(duration: 600.ms)
    .slideY(begin: 0.1, end: 0);
```

### 10.5 — Loading & Error States

Every screen should handle 3 states:
1. **Loading**: Show shimmer placeholders or `CircularProgressIndicator`.
2. **Data**: Show the actual content.
3. **Error**: Show a friendly error message with a "Retry" button.

### 10.6 — Pull-to-Refresh

Wrap your scrollable screens in `RefreshIndicator`:

```dart
RefreshIndicator(
  onRefresh: () async {
    await fetchLatestData();
  },
  child: ListView(...),
);
```

### 10.7 — Polish Checklist

| Task | Status |
|:---|:---|
| Dark theme applied globally | ⊘ (Light theme implemented matching Figma #2E7D5B palette) |
| Google Fonts (Inter) applied | ☑ Completed (`client/lib/core/theme/app_theme.dart`) |
| Sensor cards have Figma card styling | ☑ Completed (`SensorCard` with tokens from `AppColors`) |
| Entry animations on dashboard & charts | ☑ Completed (fade + slide via `flutter_animate`) |
| Loading skeletons & states across screens | ☑ Completed (shimmers on Dashboard, Charts, Alerts) |
| Error states with retry on every screen | ☑ Completed (Dashboard, Charts, and Alerts) |
| Pull-to-refresh on dashboard, charts, alerts | ☑ Completed (`RefreshIndicator` across all tabs) |
| Dynamic unread alert notification badges | ☑ Completed (NavigationBar tab & Dashboard header) |

---

---

## Appendix A — Complete API Reference

Every endpoint your Flutter app will call:

| Method | Endpoint | Auth | Purpose | Request Body | Response |
|:---|:---|:---|:---|:---|:---|
| `GET` | `/health` | None | Check if backend is alive | — | `{ "status": "ok" }` |
| `GET` | `/devices/{device_id}/status` | None | Get device online/offline status | — | `DeviceStatusResponse` |
| `GET` | `/alerts?system_id=...` | None | List alerts (filterable) | — | `{ alerts: [...], total_count: N }` |
| `PATCH` | `/alerts/{alert_id}/acknowledge` | None | Acknowledge an alert | `{ "acknowledged_by": "uuid" }` (optional) | `AlertResponse` |
| `GET` | `/systems/{system_id}/telemetry/hourly?limit=24` | None | Hourly averaged chart data | — | `[HourlyAggregationResponse, ...]` |
| `GET` | `/devices/{device_id}/relay-state` | None | Get relay desired state | — | `{ "relay_on": bool }` |
| `PUT` | `/devices/{device_id}/relay-state` | None | Set relay desired state | `{ "relay_on": bool }` | `{ "relay_on": bool }` |

> **Note on Auth**: The FastAPI backend currently uses `X-API-Key` auth for the ESP32 ingestion
> endpoint only. The read endpoints have no auth. In a production deployment, you should add
> JWT-based auth (pass the Supabase JWT in `Authorization: Bearer` header) to protect these
> endpoints. This is a future hardening task, not a blocker for development.

### Query Parameters for `GET /alerts`

| Parameter | Type | Required | Description |
|:---|:---|:---|:---|
| `system_id` | string (UUID) | ✅ Yes | Filter alerts by hydroponic system |
| `device_id` | string | No | Filter by specific device |
| `is_acknowledged` | boolean | No | `true` = acknowledged only, `false` = unacknowledged only |
| `severity` | string | No | `"critical"`, `"warning"`, or `"info"` |
| `limit` | integer | No | Max results (default: 50) |

---

## Appendix B — Database Tables the App Touches
 
| Table | App Access | How | Notes / Columns |
|:---|:---|:---|:---|
| `profiles` | SELECT own profile | Supabase SDK (RLS: own profile only) | User auth sync (`id`, `email`, `full_name`) |
| `hydroponic_systems` | SELECT systems user belongs to | Supabase SDK via `system_members` join | Multi-tenant system metadata |
| `system_members` | SELECT own memberships | Supabase SDK (RLS: own memberships) | Roles (`owner`, `operator`, `viewer`) |
| `devices` | SELECT devices + relay state | Supabase SDK / REST `GET` & `PUT /devices/{id}/relay-state` | Includes `relay_state` (Migration: `add_relay_state_to_devices.sql`) |
| `sensor_readings` | STREAM (Realtime subscribe) | Supabase Realtime WebSocket | Wide table: includes `flow_rate`, `moisture` (Migration: `add_moisture_flow_columns.sql`) |
| `alerts` | STREAM + read via API | Realtime WebSocket + `GET /alerts` | Acknowledged via `PATCH /alerts/{id}/acknowledge` |
| `telemetry_hourly_rollups` | Read via API | `GET /systems/{id}/telemetry/hourly` | SQL view aggregating averages including `avg_flow_rate`, `avg_moisture` |

---

## Appendix C — Keys & Config Reference

| Key | Where to Find | Used By | Security Level |
|:---|:---|:---|:---|
| **Supabase URL** | Supabase Dashboard → Settings → API | Flutter app + Backend | Public (OK to embed in app) |
| **Supabase Anon Key** | Supabase Dashboard → Settings → API → `anon` `public` | Flutter app ONLY | Public (respects RLS) |
| **Supabase Service Role Key** | Supabase Dashboard → Settings → API → `service_role` | Backend ONLY | 🔴 SECRET (bypasses RLS, NEVER put in client) |
| **ESP32 API Key** | `dev_secret_key_abc123` (in firmware) | ESP32 → Backend auth | Device secret |
| **Backend Base URL** | Your server IP/domain + port | Flutter app | Depends on deployment |

> ⚠️ **CRITICAL**: The Flutter app must NEVER contain the `service_role` key.
> That key bypasses all RLS and gives full database access. The app uses the `anon` key,
> which is safe to embed because RLS policies control what each user can see.

---

## 🗺️ Implementation Order Summary

```
Step 1 [✅] ──► Step 2 [✅] ──► Step 3 [✅] ──► Step 4 [✅] ──► Step 5 [✅] ──► Step 6 [✅] ──► Step 7 [✅] ──► Step 8 [✅] ──► Step 9 [✅] ──► Step 10 [✅]
  Scaffold        Auth        Navigation     System Ctx    Live Dashboard   Status Badge     Charts        Alerts      Relay Ctrl     Polish
  (Done)         (Done)         (Done)        (Done)          (Done)          (Done)          (Done)        (Done)        (Done)        (Done)
```

**Total estimated time**: 8–14 days (working part-time alongside learning).

Each step can be committed separately and tested independently. If you get stuck on Step N, Steps 1 through N-1 still work perfectly.
