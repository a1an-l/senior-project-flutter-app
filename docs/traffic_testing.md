Traffic Detection — Device Test Checklist

This document explains how to test the per-route traffic detection feature, what to watch for in logs, and example log lines you should see.

Prerequisites
- Android device (recommended) or emulator with Google Play services.
- `flutter` and `adb` on your PATH.
- App compiled with Maps API key set (see your app config).
- Location permission granted; allow background location if prompted.

Quick test steps

1) Build & run on device

```powershell
flutter run -d <device-id>
```

2) Add or ensure a saved address exists (open app → My Addresses).
3) In `My Addresses` enable the toggle for the route you want to monitor.
4) Open Traffic Settings and confirm monitoring is enabled (global setting).
5) Trigger a manual check (fast test): Traffic Settings → "Test Traffic Check".
   - This runs the same check as the background worker but immediately.

Background testing notes
- WorkManager periodic tasks use a minimum interval of 15 minutes; background checks will run on that cadence when the app is backgrounded/locked.
- On Android ensure the app is allowed to run in background / battery optimizations disabled for more reliable tests.

Log collection (Windows / PowerShell)

To stream logs and filter the app's debug prints, use:

```powershell
flutter logs | Select-String "TrafficDetection|RouteTraffic|Traffic delay detected|HiWay"
```

If you prefer `adb` directly:

```powershell
adb logcat -v time | Select-String "TrafficDetection|RouteTraffic|Traffic delay detected|HiWay"
```

Key log lines you should see (examples)

- App/background init and monitoring start

[App] Initializing background traffic service...
[TrafficDetection] Initializing notification service...
[TrafficDetection] Restarting previously enabled traffic monitoring
[RouteTraffic] startMonitoring(frequency: 15 minutes)

- Manual / periodic check

[TrafficDetection] Starting traffic check...
[TrafficDetection] Getting current location...
[TrafficDetection] Location obtained: 33.12345, -97.12345
[TrafficDetection] Checking for traffic conditions...
[TrafficDetection] Serious traffic detected: true
[TrafficDetection] Sending serious traffic notification

- Background worker (per-route checks)

Traffic delay detected — notification payload logged and stored
(You should also see an entry saved in the app's notifications list and optionally in Supabase `alerts` table.)

What to verify
- A push notification shows on the device when a condition is met.
- The notification appears in-app under Alerts (open Alerts screen).
- Supabase `alerts` table contains the saved alert (if logged in and Supabase connected).
- The saved route's per-route toggle correctly prevents/permits notifications.

Troubleshooting
- "No location": Verify device location services are on and app has permission.
- No background notifications: Check battery optimization / background restrictions on the device.
- Workmanager not triggering: Ensure `Workmanager().initialize(...)` was called in `main.dart` (it is in this project) and that the app isn't force-stopped.

Advanced: force a background run
- Lock the device and wait 15+ minutes OR use `flutter run --background` patterns; for quick functional testing rely on the "Test Traffic Check" button.

Contact / notes
- Threshold and radius are hard-coded defaults inside the services but can be tuned in `background_traffic_service.dart` and `background_tasks.dart`.
