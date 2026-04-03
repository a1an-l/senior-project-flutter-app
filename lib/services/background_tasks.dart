import 'package:workmanager/workmanager.dart';

import 'api_keys.dart';
import 'google_places_directions_service.dart';
import 'notification_service.dart';
import 'last_known_location_store.dart';
import 'saved_places.dart';
import 'package:geolocator/geolocator.dart';

const trafficCheckTaskName = 'hiwayTrafficCheck';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != trafficCheckTaskName) {
      return true;
    }

    final lastKnown = await LastKnownLocationStore.load();
    if (lastKnown == null) {
      return true;
    }
    final originLat = lastKnown.$1;
    final originLng = lastKnown.$2;

    final key = await ApiKeys.mapsApiKey();
    if (key == null || key.isEmpty) {
      return true;
    }

    final service = GooglePlacesDirectionsService(apiKey: key);

    const thresholdPct = 0.20;
    const nearMeters = 1609.0;
    final labels = await SavedPlacesStore.labels();
    for (final label in labels) {
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
      }
    }

    return true;
  });
}
