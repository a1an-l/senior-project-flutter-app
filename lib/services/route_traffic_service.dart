import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'route_monitor_store.dart';
import 'background_tasks.dart';
import 'saved_places.dart';
import 'last_known_location_store.dart';
import 'api_keys.dart';
import 'google_places_directions_service.dart';
import 'notification_service.dart';
import 'notifications_store.dart';
import 'supabase_notifications_service.dart';
import 'package:geolocator/geolocator.dart';

class RouteTrafficService {
  static const _uniqueTaskName = 'saved_route_traffic_check';

  static Future<List<String>> _loadSavedRouteLabels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? userId = prefs.getInt('user_id');
      if (userId == null) {
        return await SavedPlacesStore.labels();
      }

      final client = Supabase.instance.client;
      final data = await client
          .from('addressDB')
          .select('label')
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      final labels = List<Map<String, dynamic>>.from(data)
          .map((item) => item['label']?.toString().trim() ?? '')
          .where((label) => label.isNotEmpty)
          .toList();
      if (labels.isEmpty) {
        return await SavedPlacesStore.labels();
      }
      return labels;
    } catch (_) {
      return await SavedPlacesStore.labels();
    }
  }

  static Future<void> refreshMonitoring({int intervalMinutes = 15}) async {
    print('[RouteTraffic] refreshMonitoring(intervalMinutes: $intervalMinutes)');
    // Ensure local cache contains any server-saved addresses (geocode if needed)
    await _ensureLocalCacheFromSupabase();

    final labels = await _loadSavedRouteLabels();
    print('[RouteTraffic] Loaded saved route labels: $labels');
    if (labels.isEmpty) {
      print('[RouteTraffic] No saved route labels found, stopping monitoring');
      return stopMonitoring();
    }

    await RouteMonitorStore.ensureConfigsForLabels(labels);
    final configs = await RouteMonitorStore.loadAll();
    final enabledRoutes = labels.where((label) {
      final config = configs[label] ?? RouteMonitorConfig.defaultConfig();
      return config.enabled;
    }).toList();

    print('[RouteTraffic] Enabled routes: $enabledRoutes');
    if (enabledRoutes.isEmpty) {
      print('[RouteTraffic] No enabled routes, stopping monitoring');
      await stopMonitoring();
      return;
    }

    // Schedule background checks at a fixed 15-minute interval. WorkManager
    // enforces a minimum on Android; the app requires a 15-minute baseline
    // reset cadence, so we keep this fixed.
    final int desiredInterval = 15;

    await startMonitoring(intervalMinutes: desiredInterval);
  }

  /// Fetch server-saved addresses for the logged-in user, geocode
  /// those that lack coordinates, and cache them into `SavedPlacesStore`.
  static Future<void> _ensureLocalCacheFromSupabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? userId = prefs.getInt('user_id');
      if (userId == null) return;

      final client = Supabase.instance.client;
      final rows = await client
          .from('addressDB')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      final key = await ApiKeys.mapsApiKey();
      final hasKey = key != null && key.isNotEmpty;
      final service = hasKey ? GooglePlacesDirectionsService(apiKey: key) : null;

      for (final r in List<Map<String, dynamic>>.from(rows)) {
        final label = (r['label'] as String?)?.toString().trim() ?? '';
        if (label.isEmpty) continue;

        final existing = await SavedPlacesStore.get(label);
        if (existing != null) continue;

        double? lat;
        double? lng;
        try {
          lat = (r['lat'] as num?)?.toDouble();
        } catch (_) {
          lat = null;
        }
        try {
          lng = (r['lng'] as num?)?.toDouble();
        } catch (_) {
          lng = null;
        }

        final address = (r['address'] as String?) ?? '';
        final name = (r['name'] as String?) ?? label;
        final placeId = (r['place_id'] as String?) ?? (r['placeId'] as String?) ?? '';
        final avgSeconds = (r['avg_seconds'] as num?)?.toInt() ?? (r['avgSeconds'] as num?)?.toInt();
        final samples = (r['samples'] as num?)?.toInt();

        if (lat != null && lng != null) {
          final saved = SavedPlace(
            label: label,
            name: name,
            address: address,
            lat: lat,
            lng: lng,
            placeId: placeId,
            avgSeconds: avgSeconds,
            samples: samples,
          );
          await SavedPlacesStore.set(saved);
          continue;
        }

        if (hasKey && address.isNotEmpty && service != null) {
          try {
            final token = DateTime.now().millisecondsSinceEpoch.toString();
            final preds = await service.autocomplete(input: address, sessionToken: token);
            if (preds.isNotEmpty) {
              final details = await service.placeDetails(placeId: preds.first.placeId, sessionToken: token);
              if (details != null) {
                lat = details.lat;
                lng = details.lng;
                final resolvedName = details.name.isNotEmpty ? details.name : name;
                final resolvedPlaceId = details.placeId;
                final saved = SavedPlace(
                  label: label,
                  name: resolvedName,
                  address: address,
                  lat: lat,
                  lng: lng,
                  placeId: resolvedPlaceId,
                  avgSeconds: avgSeconds,
                  samples: samples,
                );
                await SavedPlacesStore.set(saved);
                // Attempt to persist coords back to Supabase (ignore failures)
                try {
                  if (r.containsKey('address_id')) {
                    await client
                        .from('addressDB')
                        .update({'lat': lat, 'lng': lng, 'place_id': resolvedPlaceId, 'name': resolvedName})
                        .eq('address_id', r['address_id']);
                  }
                } catch (_) {}
              }
            }
          } catch (_) {
            // ignore geocode errors
          }
        }
      }
    } catch (e) {
      // non-fatal: cache attempt failed
    }
  }

  static Future<void> startMonitoring({int intervalMinutes = 15}) async {
    // Note: Android WorkManager enforces a minimum periodic interval (≈15 minutes).
    // We still pass the requested interval (in minutes) so the app's desired
    // behavior is preserved; the OS may clamp to a higher minimum.
    print('[RouteTraffic] startMonitoring(frequency: $intervalMinutes minutes)');
    await Workmanager().registerPeriodicTask(
      _uniqueTaskName,
      trafficCheckTaskName,
      frequency: Duration(minutes: intervalMinutes),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  static Future<void> stopMonitoring() async {
    print('[RouteTraffic] stopMonitoring()');
    await Workmanager().cancelByUniqueName(_uniqueTaskName);
  }

  /// Perform a single on-demand traffic check for a saved route label.
  /// Returns a map with `detected` (bool) and `message` (String).
  static Future<Map<String, dynamic>> testRoute(String label) async {
    try {
      var saved = await SavedPlacesStore.get(label);
      if (saved == null) {
        // Try to load from Supabase (server-side saved addresses)
        final prefs = await SharedPreferences.getInstance();
        final int? userId = prefs.getInt('user_id');
        if (userId != null) {
          final client = Supabase.instance.client;
          final row = await client
              .from('addressDB')
              .select()
              .eq('user_id', userId)
              .eq('label', label)
              .maybeSingle();

          if (row != null) {
            // Try to parse coordinates if present
            double? lat;
            double? lng;
            try {
              lat = (row['lat'] as num?)?.toDouble();
            } catch (_) {
              lat = null;
            }
            try {
              lng = (row['lng'] as num?)?.toDouble();
            } catch (_) {
              lng = null;
            }

            final name = (row['name'] as String?) ?? (row['label'] as String?) ?? label;
            final address = (row['address'] as String?) ?? '';
            final placeId = (row['place_id'] as String?) ?? (row['placeId'] as String?) ?? '';
            final avgSeconds = (row['avg_seconds'] as num?)?.toInt() ?? (row['avgSeconds'] as num?)?.toInt();
            final samples = (row['samples'] as num?)?.toInt();

            if (lat != null && lng != null) {
              saved = SavedPlace(
                label: label,
                name: name,
                address: address,
                lat: lat,
                lng: lng,
                placeId: placeId,
                avgSeconds: avgSeconds,
                samples: samples,
              );
              // Cache locally for faster future access
              await SavedPlacesStore.set(saved);
            } else {
              // Try to geocode the server 'address' string using Places Autocomplete -> Place Details
              final key = await ApiKeys.mapsApiKey();
              if (key != null && key.isNotEmpty && address.isNotEmpty) {
                try {
                  final service = GooglePlacesDirectionsService(apiKey: key);
                  final token = DateTime.now().millisecondsSinceEpoch.toString();
                  final preds = await service.autocomplete(input: address, sessionToken: token);
                  if (preds.isNotEmpty) {
                    final details = await service.placeDetails(placeId: preds.first.placeId, sessionToken: token);
                    if (details != null) {
                      lat = details.lat;
                      lng = details.lng;
                      final resolvedName = details.name.isNotEmpty ? details.name : name;
                      final resolvedPlaceId = details.placeId;
                      saved = SavedPlace(
                        label: label,
                        name: resolvedName,
                        address: address,
                        lat: lat,
                        lng: lng,
                        placeId: resolvedPlaceId,
                        avgSeconds: avgSeconds,
                        samples: samples,
                      );
                      await SavedPlacesStore.set(saved);
                      // Try to persist coords back to Supabase if address_id exists
                      try {
                        if (row.containsKey('address_id')) {
                          await client
                              .from('addressDB')
                              .update({'lat': lat, 'lng': lng, 'place_id': resolvedPlaceId, 'name': resolvedName})
                              .eq('address_id', row['address_id']);
                        }
                      } catch (_) {
                        // ignore update failures (table may not have those columns)
                      }
                    }
                  }
                } catch (_) {
                  // ignore geocoding errors
                }

                if (saved == null) {
                  return {
                    'detected': false,
                    'message': 'Route "$label" exists on server but has no coordinates. Open it and select a place to save the location.'
                  };
                }
              } else {
                return {
                  'detected': false,
                  'message': 'Route "$label" exists on server but has no coordinates. Open it and select a place to save the location.'
                };
              }
            }
          } else {
            return {'detected': false, 'message': 'No saved route for "$label".'};
          }
        } else {
          return {'detected': false, 'message': 'No saved route for "$label".'};
        }
      }

      // Try to get a fresh location, fall back to last known
      double? originLat;
      double? originLng;
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
        originLat = pos.latitude;
        originLng = pos.longitude;
      } catch (_) {
        final last = await LastKnownLocationStore.load();
        if (last == null) {
          return {'detected': false, 'message': 'Unable to obtain current location.'};
        }
        originLat = last.$1;
        originLng = last.$2;
      }

      final key = await ApiKeys.mapsApiKey();
      if (key == null || key.isEmpty) {
        return {'detected': false, 'message': 'Maps API key not configured.'};
      }

      final service = GooglePlacesDirectionsService(apiKey: key);
      final directions = await service.directions(
        originLat: originLat,
        originLng: originLng,
        destLat: saved.lat,
        destLng: saved.lng,
      );

      final trafficSeconds = directions?.durationInTrafficSeconds ?? directions?.durationSeconds;
      if (trafficSeconds == null) {
        return {'detected': false, 'message': 'Could not get route duration from API.'};
      }

      final avgSeconds = saved.avgSeconds;
      if (avgSeconds == null) {
        return {'detected': false, 'message': 'No historical average available for "$label".'};
      }

      const thresholdPct = 0.20;
      final thresholdSeconds = (avgSeconds * thresholdPct).round();
      if (trafficSeconds > avgSeconds + thresholdSeconds) {
        final deltaMinutes = ((trafficSeconds - avgSeconds) / 60).round();
        final avgMinutes = (avgSeconds / 60).round();
        final nowMinutes = (trafficSeconds / 60).round();

        await NotificationService.instance.init(onTap: (_) {});
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

        return {
          'detected': true,
          'message': '${saved.name} is +$deltaMinutes min due to traffic (avg $avgMinutes → now $nowMinutes).'
        };
      }

      final avgMinutes = (avgSeconds / 60).round();
      final nowMinutes = (trafficSeconds / 60).round();
      return {
        'detected': false,
        'message': 'No significant delay for ${saved.name} (avg $avgMinutes → now $nowMinutes).'
      };
    } catch (e) {
      return {'detected': false, 'message': 'Test failed: $e'};
    }
  }

  /// Seed a baseline average for a saved route by performing one directions
  /// lookup from the current location and storing the result as the initial
  /// `avgSeconds` (samples = 1). Returns a result map with `success` and `message`.
  static Future<Map<String, dynamic>> seedBaseline(String label) async {
    try {
      var saved = await SavedPlacesStore.get(label);
      if (saved == null) {
        // Try to fetch and cache from Supabase (reuse logic from testRoute)
        final prefs = await SharedPreferences.getInstance();
        final int? userId = prefs.getInt('user_id');
        if (userId != null) {
          final client = Supabase.instance.client;
          final row = await client
              .from('addressDB')
              .select()
              .eq('user_id', userId)
              .eq('label', label)
              .maybeSingle();

          if (row != null) {
            double? lat;
            double? lng;
            try {
              lat = (row['lat'] as num?)?.toDouble();
            } catch (_) {
              lat = null;
            }
            try {
              lng = (row['lng'] as num?)?.toDouble();
            } catch (_) {
              lng = null;
            }

            final name = (row['name'] as String?) ?? (row['label'] as String?) ?? label;
            final address = (row['address'] as String?) ?? '';
            final placeId = (row['place_id'] as String?) ?? (row['placeId'] as String?) ?? '';
            final avgSeconds = (row['avg_seconds'] as num?)?.toInt() ?? (row['avgSeconds'] as num?)?.toInt();
            final samples = (row['samples'] as num?)?.toInt();

            if (lat != null && lng != null) {
              saved = SavedPlace(
                label: label,
                name: name,
                address: address,
                lat: lat,
                lng: lng,
                placeId: placeId,
                avgSeconds: avgSeconds,
                samples: samples,
              );
              await SavedPlacesStore.set(saved);
            } else {
              // try to geocode if address exists
              final key = await ApiKeys.mapsApiKey();
              if (key != null && key.isNotEmpty && address.isNotEmpty) {
                try {
                  final service = GooglePlacesDirectionsService(apiKey: key);
                  final token = DateTime.now().millisecondsSinceEpoch.toString();
                  final preds = await service.autocomplete(input: address, sessionToken: token);
                  if (preds.isNotEmpty) {
                    final details = await service.placeDetails(placeId: preds.first.placeId, sessionToken: token);
                    if (details != null) {
                      saved = SavedPlace(
                        label: label,
                        name: details.name.isNotEmpty ? details.name : name,
                        address: address,
                        lat: details.lat,
                        lng: details.lng,
                        placeId: details.placeId,
                        avgSeconds: avgSeconds,
                        samples: samples,
                      );
                      await SavedPlacesStore.set(saved);
                      // try to persist back
                      try {
                        if (row.containsKey('address_id')) {
                          await client
                              .from('addressDB')
                              .update({'lat': details.lat, 'lng': details.lng, 'place_id': details.placeId, 'name': details.name})
                              .eq('address_id', row['address_id']);
                        }
                      } catch (_) {}
                    }
                  }
                } catch (_) {}
              }
            }
          }
        }
      }

      if (saved == null) {
        return {'success': false, 'message': 'No saved route found for "$label".'};
      }

      // Get a location
      double? originLat;
      double? originLng;
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
        originLat = pos.latitude;
        originLng = pos.longitude;
      } catch (_) {
        final last = await LastKnownLocationStore.load();
        if (last == null) {
          return {'success': false, 'message': 'Unable to obtain current location.'};
        }
        originLat = last.$1;
        originLng = last.$2;
      }

      final key = await ApiKeys.mapsApiKey();
      if (key == null || key.isEmpty) {
        return {'success': false, 'message': 'Maps API key not configured.'};
      }

      final service = GooglePlacesDirectionsService(apiKey: key);
      final directions = await service.directions(
        originLat: originLat,
        originLng: originLng,
        destLat: saved.lat,
        destLng: saved.lng,
      );

      final durationSeconds = directions?.durationSeconds;
      if (durationSeconds == null) {
        return {'success': false, 'message': 'Could not obtain duration to seed baseline.'};
      }

      // Save as initial average
      final seeded = SavedPlace(
        label: saved.label,
        name: saved.name,
        address: saved.address,
        lat: saved.lat,
        lng: saved.lng,
        placeId: saved.placeId,
        avgSeconds: durationSeconds,
        samples: 1,
      );
      await SavedPlacesStore.set(seeded);

      // persist to Supabase if possible
      try {
        final prefs = await SharedPreferences.getInstance();
        final int? userId = prefs.getInt('user_id');
        if (userId != null) {
          final client = Supabase.instance.client;
          // Best-effort update by label for this user
          await client
              .from('addressDB')
              .update({'avg_seconds': durationSeconds, 'samples': 1})
              .eq('user_id', userId)
              .eq('label', label);
        }
      } catch (_) {}

      final mins = (durationSeconds / 60).round();
      return {'success': true, 'message': 'Baseline seeded: $mins min for "$label".'};
    } catch (e) {
      return {'success': false, 'message': 'Seed failed: $e'};
    }
  }
}
