import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_keys.dart';
import 'google_places_directions_service.dart';
import 'notification_service.dart';
import 'last_known_location_store.dart';
import 'saved_places.dart';
import 'route_monitor_store.dart';
import 'notifications_store.dart';
import 'supabase_notifications_service.dart';
import 'package:geolocator/geolocator.dart';

const trafficCheckTaskName = 'hiwayTrafficCheck';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != trafficCheckTaskName) {
      return true;
    }

    // Try to get a fresh/current position; fall back to last known.
    double? originLat;
    double? originLng;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 8),
      );
      originLat = pos.latitude;
      originLng = pos.longitude;
    } catch (_) {
      final lastKnown = await LastKnownLocationStore.load();
      if (lastKnown == null) return true;
      originLat = lastKnown.$1;
      originLng = lastKnown.$2;
    }

    final key = await ApiKeys.mapsApiKey();
    if (key == null || key.isEmpty) {
      return true;
    }

    final service = GooglePlacesDirectionsService(apiKey: key);

    const thresholdPct = 0.20;
    const nearMeters = 1609.0;
    const dedupeWindowMs = 60 * 60 * 1000; // 60 minutes
    final labels = await SavedPlacesStore.labels();

    // Initialize notifications once per background run
    await NotificationService.instance.init(onTap: (_) {});

    // Best-effort initialize Supabase in this background isolate so we can
    // persist alerts to the DB from background tasks.
    try {
      await Supabase.initialize(
        url: 'https://mzpdwpmbtsnenqqvhjzo.supabase.co/',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im16cGR3cG1idHNuZW5xcXZoanpvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE0MzgzOTcsImV4cCI6MjA4NzAxNDM5N30._RdzvMz7-IjUDnxeRRJ3kbK7RAvVSt2D9TKUy9XHxFw',
      );
    } catch (_) {
      // ignore - Supabase may already be initialized in this process
    }

    for (final label in labels) {
      final monitor = await RouteMonitorStore.load(label) ?? RouteMonitorConfig.defaultConfig();
      // Skip disabled or out-of-window routes
      if (!monitor.enabled) continue;
      if (!monitor.isActiveAt(DateTime.now())) continue;

      final saved = await SavedPlacesStore.get(label);
      final avgSeconds = saved?.avgSeconds;
      if (saved == null || avgSeconds == null) {
        continue;
      }

      final distToDest = Geolocator.distanceBetween(
        originLat,
        originLng,
        saved.lat,
        saved.lng,
      );
      if (distToDest <= nearMeters) {
        continue;
      }

      final directions = await service.directions(
        originLat: originLat,
        originLng: originLng,
        destLat: saved.lat,
        destLng: saved.lng,
      );

      final trafficSeconds = directions?.durationInTrafficSeconds ?? directions?.durationSeconds;
      if (trafficSeconds == null) {
        continue;
      }

      // Auto-reset baseline automatically every 15 minutes for enabled routes.
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      const autoResetIntervalMs = 15 * 60 * 1000; // 15 minutes
      final last = monitor.lastResetAtMs;
      if (last == 0 || (nowMs - last) >= autoResetIntervalMs) {
        final existingAvg = saved.avgSeconds;
        final existingSamples = saved.samples ?? 0;
        int newAvg;
        int newSamples;
        if (existingAvg == null || existingSamples <= 0) {
          newAvg = trafficSeconds;
          newSamples = 1;
        } else {
          newSamples = existingSamples + 1;
          newAvg = ((existingAvg * existingSamples) + trafficSeconds) ~/ newSamples;
        }

        final updatedSaved = SavedPlace(
          label: saved.label,
          name: saved.name,
          address: saved.address,
          lat: saved.lat,
          lng: saved.lng,
          placeId: saved.placeId,
          avgSeconds: newAvg,
          samples: newSamples,
        );
        await SavedPlacesStore.set(updatedSaved);

        final updatedMonitor = RouteMonitorConfig(
          enabled: monitor.enabled,
          startHour: monitor.startHour,
          startMinute: monitor.startMinute,
          endHour: monitor.endHour,
          endMinute: monitor.endMinute,
          autoResetBaseline: monitor.autoResetBaseline,
          autoResetIntervalMinutes: monitor.autoResetIntervalMinutes,
          lastResetAtMs: nowMs,
        );
        await RouteMonitorStore.save(label, updatedMonitor);

        // After seeding/resetting baseline, skip detection this run to avoid false alert
        continue;
      }

      final thresholdSeconds = (avgSeconds * thresholdPct).round();
      if (trafficSeconds > avgSeconds + thresholdSeconds) {
        final deltaMinutes = ((trafficSeconds - avgSeconds) / 60).round();
        final avgMinutes = (avgSeconds / 60).round();
        final nowMinutes = (trafficSeconds / 60).round();

        // Deduplicate recent alerts for this route (local + server check)
        try {
          final recent = await NotificationsStore.list();
          HiWayNotification? lastLocal;
          try {
            lastLocal = recent.firstWhere((n) => n.title == saved.name);
          } catch (_) {
            lastLocal = null;
          }

          final now = DateTime.now().millisecondsSinceEpoch;
          if (lastLocal != null && (now - lastLocal.createdAtMs) < dedupeWindowMs) {
            // Skip sending duplicate alert
            continue;
          }

          // Server-side dedupe: query recent alerts for this user matching the route
          try {
            final prefs = await SharedPreferences.getInstance();
            final int? userId = prefs.getInt('user_id');
            if (userId != null) {
              final sinceIso = DateTime.fromMillisecondsSinceEpoch(now - dedupeWindowMs).toUtc().toIso8601String();
              final rows = await Supabase.instance.client
                  .from('alerts')
                  .select()
                  .eq('user_id', userId)
                  .gte('timestamp', sinceIso)
                  .ilike('alert_msg', '${saved.name}%');
              if (rows is List && rows.isNotEmpty) {
                continue; // recent server alert exists
              }
            }
          } catch (_) {
            // ignore server dedupe failures
          }
        } catch (_) {}

        await NotificationService.instance.showTrafficAlert(
          title: 'Traffic delay detected',
          body: '${saved.name} is +$deltaMinutes min due to traffic (avg $avgMinutes → now $nowMinutes).',
          payload: 'reroute',
        );

        final notification = HiWayNotification(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: saved.name,
          subtitle: saved.address,
          detail: '+$deltaMinutes min due to traffic',
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          read: false,
          urgent: true,
        );
        await NotificationsStore.add(notification);
        await SupabaseNotificationsService().saveNotification(
          title: notification.title,
          subtitle: notification.subtitle,
          detail: notification.detail,
          createdAtMs: notification.createdAtMs,
        );
      }
    }

    return true;
  });
}
