import 'package:flutter/material.dart';
import 'app_drawer.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/api_keys.dart';
import '../services/google_places_directions_service.dart';
import '../services/saved_places.dart';
import '../services/route_service.dart';
import '../services/history_service.dart';

// --- Manual Track Imports ---
import '../services/route_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// --- Main Branch Imports ---
import '../services/last_known_location_store.dart';
import '../services/notification_service.dart';
import '../services/background_tasks.dart';
import 'package:workmanager/workmanager.dart';
import '../services/notifications_store.dart';
import '../services/supabase_notifications_service.dart';
import 'notifications_page.dart';
import 'location_input_page.dart';
import 'history_page.dart';

class HomeMapPage extends StatefulWidget {
  const HomeMapPage({super.key});

  @override
  State<HomeMapPage> createState() => _HomeMapPageState();
}

class _HomeMapPageState extends State<HomeMapPage> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  int bottomIndex = 0;
  GoogleMapController? controller;
  bool myLocationEnabled = false;
  Position? currentPosition;
  StreamSubscription<Position>? positionSubscription;
  bool followUser = true;
  String? mapsApiKey;

  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  List<PlaceSuggestion> suggestions = [];
  bool searching = false;
  PlaceDetails? selectedPlace;
  String sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
  DirectionsResult? selectedDirections;
  List<String> recentSearches = [];
  bool searchExpanded = false;

  Set<Marker> markers = {};
  Set<Polyline> polylines = {};

  // --- Route Tracking & History Variables ---
  bool isTracking = false;
  List<LatLng> trackedRoutePoints = [];
  final RouteService _routeService = RouteService();
  final HistoryService _historyService = HistoryService();

  // --- Main Branch Variables ---
  Timer? inAppTrafficTimer;
  bool navigationActive = false;
  int navigationStepIndex = 0;
  bool hasUnreadNotifications = false;

  // --- New Rerouting & Camera Variables ---
  bool isRerouting = false;
  int offRouteCount = 0;
  final double arrivalThresholdMeters = 50.0;
  bool _isProgrammaticCameraMove = false;
  final double offRouteThresholdMeters = 75.0; // Reroute if >75m off path

  static const CameraPosition initialCameraPosition = CameraPosition(
    target: LatLng(26.3017, -98.1633),
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    print("🛑 DEBUG: initState called. Initializing map page...");
    _initLocation();
    _loadApiKey();
    _loadRecentSearches();
    _refreshUnread();
    searchController.addListener(_onSearchChanged);
    searchFocusNode.addListener(() {
      if (mounted) {
        setState(() {
          searchExpanded = searchFocusNode.hasFocus;
        });
      }
    });
  }

  Future<void> _refreshUnread() async {
    final hasUnread = await NotificationsStore.hasUnread();
    if (!mounted) {
      return;
    }
    setState(() => hasUnreadNotifications = hasUnread);
  }

  Future<void> _loadApiKey() async {
    print("🛑 DEBUG: Attempting to load API Key...");
    try {
      final key = await ApiKeys.mapsApiKey();
      if (!mounted) return;
      setState(() => mapsApiKey = key);
      print("🛑 DEBUG: API Key loaded successfully.");
    } catch (e) {
      print("🛑 DEBUG ERROR: Failed to load API key! Error: $e");
    }
  }

  // --- Feature 2: Off-Route Detection ---
  bool _isUserOffRoute(Position currentPos) {
    if (selectedDirections == null) return false;

    double minDistance = double.infinity;
    // Find the closest point on our current polyline to the user
    for (var p in selectedDirections!.polylinePoints) {
      final dist = Geolocator.distanceBetween(
          currentPos.latitude, currentPos.longitude, p[0], p[1]);
      if (dist < minDistance) {
        minDistance = dist;
      }
    }
    return minDistance > offRouteThresholdMeters;
  }

  // --- Feature 2: Recalculate Route ---
  Future<void> _recalculateRoute(Position currentPos) async {
    // Prevent multiple simultaneous API calls
    if (isRerouting || selectedPlace == null || googleService == null) return;

    setState(() => isRerouting = true);
    print("🛑 DEBUG: User off route. Recalculating directions...");

    try {
      final directions = await googleService!.directions(
        originLat: currentPos.latitude,
        originLng: currentPos.longitude,
        destLat: selectedPlace!.lat,
        destLng: selectedPlace!.lng,
        alternatives: false,
      );

      if (directions != null && mounted) {
        final points = directions.polylinePoints.map((p) => LatLng(p[0], p[1])).toList(growable: false);

        setState(() {
          selectedDirections = directions;
          polylines.removeWhere((p) => p.polylineId == const PolylineId('route'));
          polylines.add(Polyline(
            polylineId: const PolylineId('route'),
            points: points,
            width: 5,
            color: const Color(0xFF2F5CE5),
          ));
          navigationStepIndex = 0; // Reset steps to the beginning of new route
        });
        print("🛑 DEBUG: Rerouting successful.");
      }
    } catch (e) {
      print("🛑 DEBUG ERROR: Rerouting failed: $e");
    } finally {
      if (mounted) setState(() => isRerouting = false);
    }
  }

  @override
  void dispose() {
    positionSubscription?.cancel();
    inAppTrafficTimer?.cancel();
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  // --- Play/Pause Tracking Logic ---
  Future<void> _toggleTracking() async {
    if (isTracking) {
      // 1. STOP TRACKING
      setState(() {
        isTracking = false;
      });

      // Let the screen go to sleep normally again
      WakelockPlus.disable();

      if (trackedRoutePoints.length >= 2) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final int? actualUserId = prefs.getInt('user_id');

          if (actualUserId == null) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in to save routes!'), backgroundColor: Colors.orange));
            return;
          }
          await _routeService.saveNewRoute(trackedRoutePoints, actualUserId);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Route saved successfully!'), backgroundColor: Colors.green));
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save route: $e'), backgroundColor: Colors.red));
        }
      }
    } else {
      setState(() {
        isTracking = true;
        trackedRoutePoints.clear();

        // Keep the screen awake while tracking
        WakelockPlus.enable();
        polylines.removeWhere((p) => p.polylineId == const PolylineId('tracked_route'));
        if (currentPosition != null) {
          trackedRoutePoints.add(LatLng(currentPosition!.latitude, currentPosition!.longitude));
        }
      });
    }
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList('recent_searches') ?? [];
    if (!mounted) return;
    setState(() => recentSearches = values);
  }

  Future<void> _addRecentSearch(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final next = <String>[trimmed, ...recentSearches.where((e) => e != trimmed)];
    final capped = next.length > 6 ? next.sublist(0, 6) : next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_searches', capped);
    if (!mounted) return;
    setState(() => recentSearches = capped);
  }

  GooglePlacesDirectionsService? get googleService {
    final apiKey = mapsApiKey;
    if (apiKey == null || apiKey.isEmpty) return null;
    return GooglePlacesDirectionsService(apiKey: apiKey);
  }

  Future<void> _initLocation() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
    if (!mounted) return;

    setState(() => myLocationEnabled = true);
    final Position position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
    currentPosition = position;

    positionSubscription?.cancel();
    positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 1), //High-frequency polling, updates every 1 meter for smoothness
    ).listen((p) async {
      currentPosition = p;
      await LastKnownLocationStore.save(lat: p.latitude, lng: p.longitude);
      if (!mounted) return;

      if (isTracking) {
        setState(() {
          trackedRoutePoints.add(LatLng(p.latitude, p.longitude));
          polylines.removeWhere((poly) => poly.polylineId == const PolylineId('tracked_route'));
          polylines.add(Polyline(polylineId: const PolylineId('tracked_route'), points: List.from(trackedRoutePoints), width: 6, color: Colors.redAccent));
        });
      }

      if (navigationActive) {
        await _updateNavigationProgress(p);

        // 1. ARRIVAL DETECTION
        if (selectedPlace != null) {
          final distToDest = Geolocator.distanceBetween(
              p.latitude, p.longitude, selectedPlace!.lat, selectedPlace!.lng);

          if (distToDest <= arrivalThresholdMeters) {
            _stopInAppNavigation(); // Stops tracking, resets UI
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🎉 You have reached your destination!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 4),
                ),
              );
            }
            return; // Stop processing further for this tick
          }
        }

        // 2. ANTI-FLAPPING REROUTE (Debounce)
        if (_isUserOffRoute(p)) {
          offRouteCount++;
          if (offRouteCount >= 3) {
            _recalculateRoute(p);
            offRouteCount = 0;
          }
        } else {
          offRouteCount = 0;
        }

        // --- NEW: 3. "EAT" THE ROUTE BEHIND THE USER ---
        if (selectedDirections != null && selectedDirections!.polylinePoints.isNotEmpty) {
          int closestIndex = 0;
          double minDistance = double.infinity;

          for (int i = 0; i < selectedDirections!.polylinePoints.length; i++) {
            final point = selectedDirections!.polylinePoints[i];
            final dist = Geolocator.distanceBetween(p.latitude, p.longitude, point[0], point[1]);
            if (dist < minDistance) {
              minDistance = dist;
              closestIndex = i;
            }
          }

          // If we have passed a few points, slice them off the array and redraw
          if (closestIndex > 2) {
            selectedDirections!.polylinePoints.removeRange(0, closestIndex - 1);

            final updatedPoints = selectedDirections!.polylinePoints
                .map((pt) => LatLng(pt[0], pt[1]))
                .toList(growable: false);

            setState(() {
              polylines.removeWhere((poly) => poly.polylineId == const PolylineId('route'));
              polylines.add(Polyline(
                polylineId: const PolylineId('route'),
                points: updatedPoints,
                width: 5,
                color: const Color(0xFF2F5CE5),
              ));
            });
          }
        }
        // --- END OF EAT ROUTE LOGIC ---
      }

      if (followUser && controller != null) {
        _isProgrammaticCameraMove = true; // Tell the map WE are moving the camera
        // --- NEW: Dynamic Navigation Camera ---
        if (navigationActive) {
          await controller!.animateCamera(CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(p.latitude, p.longitude),
              zoom: 18.5,       // Zoom in close
              tilt: 55.0,       // 3D Tilt effect
              bearing: p.heading, // Rotate map to match user's travel direction
            ),
          ));
        } else {
          // Standard top-down follow
          await controller!.animateCamera(CameraUpdate.newLatLng(LatLng(p.latitude, p.longitude)));
        }
        // Allow gestures to register again after the animation completes
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _isProgrammaticCameraMove = false;
        });
      }
    });

    if (!mounted) return;
    final GoogleMapController? currentController = controller;
    if (currentController == null) return;
    await currentController.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 15)));
  }

  Future<void> _onSearchChanged() async {
    final text = searchController.text.trim();
    if (!searchFocusNode.hasFocus) return;
    if (text.isEmpty) {
      if (mounted) setState(() => suggestions = []);
      return;
    }

    final service = googleService;
    if (service == null) return;

    setState(() => searching = true);
    try {
      final results = await service.autocomplete(input: text, sessionToken: sessionToken);
      if (!mounted) return;
      setState(() {
        suggestions = results;
        searching = false;
      });
    } catch (e) {
      print("🛑 DEBUG ERROR: Autocomplete failed! Exception: $e");
      if (!mounted) return;
      setState(() => searching = false);
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    final service = googleService;
    if (service == null) return;
    final origin = currentPosition;
    if (origin == null) return;

    searchFocusNode.unfocus();
    setState(() {
      searchExpanded = false;
      suggestions = [];
      searching = true;
      selectedPlace = null;
      selectedDirections = null;
      polylines.removeWhere((p) => p.polylineId != const PolylineId('tracked_route'));
      markers = {};
    });

    try {
      final details = await service.placeDetails(placeId: suggestion.placeId, sessionToken: sessionToken);
      if (!mounted || details == null) return;

      final directions = await service.directions(originLat: origin.latitude, originLng: origin.longitude, destLat: details.lat, destLng: details.lng);

      if (!mounted) return;

      final destLatLng = LatLng(details.lat, details.lng);
      final newMarkers = <Marker>{
        Marker(markerId: const MarkerId('destination'), position: destLatLng, infoWindow: InfoWindow(title: details.name)),
      };

      final newPolylines = Set<Polyline>.from(polylines);
      if (directions != null) {
        final points = directions.polylinePoints.map((p) => LatLng(p[0], p[1])).toList(growable: false);
        newPolylines.add(Polyline(polylineId: const PolylineId('route'), points: points, width: 5, color: const Color(0xFF2F5CE5)));
        final bounds = _boundsFor(points);
        await controller?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
      } else {
        await controller?.animateCamera(CameraUpdate.newLatLngZoom(destLatLng, 14));
      }

      setState(() {
        selectedPlace = details;
        selectedDirections = directions;
        markers = newMarkers;
        polylines = newPolylines;
        searching = false;
        searchController.text = details.name.isEmpty ? suggestion.description : details.name;
        sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
      });
      await _addRecentSearch(suggestion.description);
    } catch (e) {
      if (mounted) setState(() => searching = false);
    }
  }

  Future<void> _selectRecentSearch(String query) async {
    print("🛑 DEBUG: _selectRecentSearch triggered for query: '$query'");
    final service = googleService;
    if (service == null) {
      print("🛑 DEBUG ERROR: googleService is null!");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Google API is not configured.'), backgroundColor: Colors.red));
      return;
    }

    setState(() {
      searching = true;
      suggestions = [];
    });

    try {
      final results = await service.autocomplete(input: query, sessionToken: sessionToken);

      if (!mounted) return;
      setState(() => searching = false);

      if (results.isEmpty) {
        print("🛑 DEBUG: No results found for '$query'.");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google could not find any results for "$query".'), backgroundColor: Colors.orange));
        return;
      }

      await _selectSuggestion(results.first);
    } catch (e) {
      print("🛑 DEBUG ERROR: Manual search failed: $e");
      if (!mounted) return;
      setState(() => searching = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _routeToSavedLabel(String label) async {
    final saved = await SavedPlacesStore.get(label);
    if (!mounted) return;

    if (saved == null) {
      final result = await Navigator.push<SavedPlace>(
        context,
        MaterialPageRoute(builder: (_) => LocationInputPage(title: label, placeholder: 'Enter $label address')),
      );
      if (!mounted || result == null) return;
      await _routeToPlace(result);
      return;
    }
    await _routeToPlace(saved);
  }

  Future<void> _routeToPlace(SavedPlace place) async {
    final origin = currentPosition;
    final service = googleService;
    if (origin == null || service == null) return;

    setState(() {
      searching = true;
      selectedPlace = PlaceDetails(placeId: place.placeId, name: place.name, formattedAddress: place.address, lat: place.lat, lng: place.lng);
      selectedDirections = null;
      navigationActive = false;
      polylines.removeWhere((p) => p.polylineId != const PolylineId('tracked_route'));
      markers = {};
    });

    final directions = await service.directions(
      originLat: origin.latitude,
      originLng: origin.longitude,
      destLat: place.lat,
      destLng: place.lng,
    );

    final durationSeconds = directions?.durationSeconds;
    if (durationSeconds != null) {
      final currentAvg = place.avgSeconds;
      final currentSamples = place.samples;
      final nextSamples = (currentSamples ?? 0) + 1;
      final nextAvg = currentAvg == null
          ? durationSeconds
          : ((currentAvg * (currentSamples ?? 0)) + durationSeconds) ~/ nextSamples;

      await SavedPlacesStore.set(
        SavedPlace(
          label: place.label,
          name: place.name,
          address: place.address,
          lat: place.lat,
          lng: place.lng,
          placeId: place.placeId,
          avgSeconds: nextAvg,
          samples: nextSamples,
        ),
      );
    }

    if (!mounted) {
      return;
    }

    if (!mounted) return;
    final destLatLng = LatLng(place.lat, place.lng);
    final newMarkers = <Marker>{Marker(markerId: MarkerId('saved_${place.label.toLowerCase()}'), position: destLatLng, infoWindow: InfoWindow(title: place.name))};
    final newPolylines = Set<Polyline>.from(polylines);
    if (directions != null) {
      final points = directions.polylinePoints.map((p) => LatLng(p[0], p[1])).toList(growable: false);
      newPolylines.add(Polyline(polylineId: const PolylineId('route'), points: points, width: 5, color: const Color(0xFF2F5CE5)));
      final bounds = _boundsFor(points);
      await controller?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
    } else {
      await controller?.animateCamera(CameraUpdate.newLatLngZoom(destLatLng, 14));
    }

    setState(() {
      selectedDirections = directions;
      markers = newMarkers;
      polylines = newPolylines;
      searching = false;
      searchController.text = place.name;
    });

    await _startMonitoringFor(place: place, directions: directions);
  }

  Future<void> _startMonitoringFor({required SavedPlace place, required DirectionsResult? directions}) async {
    final origin = currentPosition;
    if (origin != null) {
      await LastKnownLocationStore.save(lat: origin.latitude, lng: origin.longitude);
    }

    await Workmanager().registerPeriodicTask(
      'traffic_check',
      trafficCheckTaskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

    inAppTrafficTimer?.cancel();
    inAppTrafficTimer = Timer.periodic(const Duration(minutes: 2), (_) => _checkTrafficNow());
  }

  Future<void> _checkTrafficNow() async {
    final origin = currentPosition;
    final service = googleService;
    if (!mounted || origin == null || service == null) {
      return;
    }

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
        origin.latitude,
        origin.longitude,
        saved.lat,
        saved.lng,
      );
      if (distToDest <= nearMeters) {
        continue;
      }

      final directions = await service.directions(
        originLat: origin.latitude,
        originLng: origin.longitude,
        destLat: saved.lat,
        destLng: saved.lng,
        alternatives: true,
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
        if (selectedPlace?.placeId == saved.placeId && directions != null) {
          final points = directions.polylinePoints
              .map((p) => LatLng(p[0], p[1]))
              .toList(growable: false);
          setState(() {
            selectedDirections = directions;
            polylines = {
              Polyline(
                polylineId: const PolylineId('route'),
                points: points,
                width: 5,
                color: const Color(0xFF2F5CE5),
              ),
            };
            navigationStepIndex = 0;
          });
        }

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
        
        // Also save to Supabase
        await SupabaseNotificationsService().saveNotification(
          title: notification.title,
          subtitle: notification.subtitle,
          detail: notification.detail,
          createdAtMs: notification.createdAtMs,
        );
        await _refreshUnread();
      }
    }
  }

  void _stopInAppNavigation() {
    setState(() {
      navigationActive = false;
      navigationStepIndex = 0;

      // --- NEW: Clear map data completely upon stopping/arrival ---
      selectedPlace = null;
      selectedDirections = null;
      searchController.clear();
      polylines.removeWhere((p) => p.polylineId != const PolylineId('tracked_route'));
      markers = {};
    });
  }

  Future<void> _updateNavigationProgress(Position position) async {
    final directions = selectedDirections;
    if (directions == null || directions.steps.isEmpty) {
      return;
    }
    if (navigationStepIndex >= directions.steps.length) {
      _stopInAppNavigation();
      return;
    }

    final step = directions.steps[navigationStepIndex];
    final distanceMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      step.endLat,
      step.endLng,
    );

    if (distanceMeters < 35) {
      if (!mounted) {
        return;
      }
      setState(() => navigationStepIndex += 1);
      if (navigationStepIndex >= directions.steps.length) {
        _stopInAppNavigation();
      }
    }
  }

  // --- Start Navigation & Save to History ---
  Future<void> _startInAppNavigation() async {
    setState(() {
      navigationActive = true;
      followUser = true;
    });
    // --- NEW: Lock the map from registering a user swipe during the swoop ---
    _isProgrammaticCameraMove = true;
    // --- NEW: Swoop camera into Navigation Mode immediately ---
    if (currentPosition != null && controller != null) {
      await controller!.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(currentPosition!.latitude, currentPosition!.longitude),
          zoom: 18.5,
          tilt: 55.0,
          bearing: currentPosition!.heading,
        ),
      ));
    }

    // Release the lock after the animation finishes (1 second is safe)
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _isProgrammaticCameraMove = false;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? currentUserId = prefs.getInt('user_id');

      if (currentUserId != null && selectedPlace != null) {
        String startLabel = 'Current Location';
        String destLabel = selectedPlace!.formattedAddress.isNotEmpty ? selectedPlace!.formattedAddress : selectedPlace!.name;
        await _historyService.saveToHistory(userId: currentUserId, startAddress: startLabel, destinationAddress: destLabel);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip Saved to History!'), backgroundColor: Colors.green));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Log in to save history.'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      print("🛑 DEBUG ERROR: Failed to save to history: $e");
    }
  }

  LatLngBounds _boundsFor(List<LatLng> points) {
    double? minLat, maxLat, minLng, maxLng;
    for (final p in points) {
      minLat = minLat == null ? p.latitude : (p.latitude < minLat ? p.latitude : minLat);
      maxLat = maxLat == null ? p.latitude : (p.latitude > maxLat ? p.latitude : maxLat);
      minLng = minLng == null ? p.longitude : (p.longitude < minLng ? p.longitude : minLng);
      maxLng = maxLng == null ? p.longitude : (p.longitude > maxLng ? p.longitude : maxLng);
    }
    return LatLngBounds(southwest: LatLng(minLat ?? 0, minLng ?? 0), northeast: LatLng(maxLat ?? 0, maxLng ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      drawer: const AppDrawer(),

      appBar: AppBar(
        backgroundColor: const Color(0xFF2F5CE5),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('HiWay', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: initialCameraPosition,
            myLocationEnabled: myLocationEnabled,
            myLocationButtonEnabled: true, // Native button re-enabled for demo
            zoomControlsEnabled: false,
            markers: markers,
            polylines: polylines,

            // --- NEW: Use the built-in callback, but check our flag ---
            onCameraMoveStarted: () {
              // Only trigger if we are navigating AND the code isn't moving the camera
              if (navigationActive && !_isProgrammaticCameraMove) {
                setState(() => followUser = false);
              }
            },

            onTap: (_) => FocusScope.of(context).unfocus(),
            onMapCreated: (value) {
              controller = value;
              if (myLocationEnabled) _initLocation();
            },
          ),

          if (searchExpanded)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  FocusScope.of(context).unfocus();
                  setState(() => searchExpanded = false);
                },
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TopChip(label: 'Home', icon: Icons.home_outlined, onPressed: () => _routeToSavedLabel('Home')),
                    const SizedBox(width: 8),
                    _TopChip(label: 'Work', icon: Icons.work_outline, onPressed: () => _routeToSavedLabel('Work')),
                    const SizedBox(width: 8),
                    _TopChip(
                      label: 'New', icon: Icons.add,
                      onPressed: () {
                        setState(() => searchExpanded = true);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) FocusScope.of(context).requestFocus(searchFocusNode);
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            left: 16, right: 16,
            top: searchExpanded ? 62 : null,
            bottom: searchExpanded ? null : 10,
            child: SafeArea(
              top: searchExpanded, bottom: !searchExpanded,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E5E5)),
                      boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 6))],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 10),
                        const Icon(Icons.search, size: 18, color: Color(0xFF8A8A8A)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            focusNode: searchFocusNode,
                            readOnly: !searchExpanded,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (value) async {
                              FocusScope.of(context).unfocus();
                              print("🛑 DEBUG: Keyboard 'Enter' pressed with value: '$value'");
                              if (value.trim().isEmpty) return;
                              if (suggestions.isNotEmpty) {
                                _selectSuggestion(suggestions.first);
                              } else {
                                await _selectRecentSearch(value);
                              }
                            },
                            onTap: () {
                              if (!searchExpanded) {
                                setState(() => searchExpanded = true);
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) FocusScope.of(context).requestFocus(searchFocusNode);
                                });
                              }
                            },
                            decoration: const InputDecoration(hintText: 'Search', border: InputBorder.none, isDense: true),
                          ),
                        ),
                        if (searching)
                          const SizedBox(width: 28, height: 28, child: Padding(padding: EdgeInsets.all(6), child: CircularProgressIndicator(strokeWidth: 2)))
                        else if (searchExpanded && searchController.text.isNotEmpty)
                          IconButton(
                            onPressed: () {
                              setState(() {
                                searchController.clear();
                                suggestions = [];
                                selectedPlace = null;
                                selectedDirections = null;
                                navigationActive = false;
                                polylines.removeWhere((p) => p.polylineId != const PolylineId('tracked_route'));
                                markers = {};
                              });
                            },
                            icon: const Icon(Icons.close, size: 18),
                          ),
                      ],
                    ),
                  ),
                  if (searchExpanded && (suggestions.isNotEmpty || (searchController.text.isEmpty && recentSearches.isNotEmpty)))
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E5E5)),
                        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 6))],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (searchController.text.isEmpty && recentSearches.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
                              child: Row(
                                children: [
                                  Text(
                                    'Recent',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          if (searchController.text.isEmpty && recentSearches.isNotEmpty)
                            ListView.separated(
                              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: recentSearches.length, separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final value = recentSearches[index];
                                return ListTile(dense: true, leading: const Icon(Icons.history, size: 18, color: Color(0xFF8A8A8A)), title: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)), onTap: () => _selectRecentSearch(value));
                              },
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: suggestions.length > 6 ? 6 : suggestions.length, separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final s = suggestions[index];
                                return ListTile(dense: true, title: Text(s.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)), onTap: () => _selectSuggestion(s));
                              },
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // --- Top UI Panel: Hidden during active navigation ---
          if (selectedPlace != null && !navigationActive)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 86),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E5E5)),
                      boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 8))],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(selectedPlace!.name.isEmpty ? selectedPlace!.formattedAddress : selectedPlace!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              _RouteInfoRow(directions: selectedDirections),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (selectedDirections != null)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2F5CE5),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              minimumSize: const Size(0, 0),
                            ),
                            onPressed: navigationActive ? _stopInAppNavigation : _startInAppNavigation,
                            child: Text(
                              navigationActive ? 'Stop' : 'Start',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              searchController.clear();
                              suggestions = [];
                              selectedPlace = null;
                              selectedDirections = null;
                              navigationActive = false;
                              polylines.removeWhere((p) => p.polylineId != const PolylineId('tracked_route'));
                              markers = {};
                            });
                            _stopInAppNavigation();
                            Workmanager().cancelByUniqueName('traffic_check');
                            inAppTrafficTimer?.cancel();
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: navigationActive
          ? _NavigationBanner(
        directions: selectedDirections,
        stepIndex: navigationStepIndex,
        onTap: _stopInAppNavigation,
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: BottomAppBar(
        height: 70, padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            _BottomItem(
              icon: hasUnreadNotifications ? Icons.notifications : Icons.notifications_none, 
              label: 'Alerts', 
              selected: false, 
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                );
                await _refreshUnread();
              },
                ),
            const Spacer(),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isTracking ? Colors.red : const Color(0xFF2F5CE5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _toggleTracking,
                icon: Icon(
                  isTracking ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
              ),
            ),
            const Spacer(),
            _BottomItem(
              icon: Icons.history,
              label: 'History',
              selected: bottomIndex == 1,
              onPressed: () {Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HistoryPage())).then((_) {
                setState(() => bottomIndex = 0);
              });
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TopChip extends StatelessWidget {
  const _TopChip({required this.label, required this.icon, required this.onPressed});
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed, icon: Icon(icon, size: 18), label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, backgroundColor: Colors.white, side: const BorderSide(color: Color(0xFFE5E5E5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), minimumSize: const Size(0, 38)),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({required this.icon, required this.label, required this.selected, required this.onPressed});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? const Color(0xFF2F5CE5) : const Color(0xFF8A8A8A);
    return TextButton(
      onPressed: onPressed, style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(64, 48), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color), const SizedBox(height: 2), Text(label, style: TextStyle(fontSize: 11, color: color))]),
    );
  }
}

class _RouteInfoRow extends StatelessWidget {
  const _RouteInfoRow({required this.directions});
  final DirectionsResult? directions;

  @override
  Widget build(BuildContext context) {
    final distance = directions?.distanceText;
    final duration = directions?.durationText;
    final durationTraffic = directions?.durationInTrafficText;
    final durationSeconds = directions?.durationSeconds;
    final durationTrafficSeconds = directions?.durationInTrafficSeconds;
    final bool hasTrafficDelay = durationSeconds != null && durationTrafficSeconds != null && durationTrafficSeconds > durationSeconds;
    final parts = <Widget>[];

    if (distance != null && distance.isNotEmpty) parts.add(_pill(text: distance, color: const Color(0xFFF4F4F4), textColor: Colors.black87));
    final effectiveDuration = (durationTraffic != null && durationTraffic.isNotEmpty) ? durationTraffic : duration;
    if (effectiveDuration != null && effectiveDuration.isNotEmpty) parts.add(_pill(text: effectiveDuration, color: hasTrafficDelay ? const Color(0xFFFFEBEE) : const Color(0xFFEAF1FF), textColor: hasTrafficDelay ? const Color(0xFFC62828) : const Color(0xFF2F5CE5)));

    return Wrap(spacing: 8, runSpacing: 8, children: parts.isEmpty ? [const Text('Directions unavailable', style: TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)))] : parts);
  }

  Widget _pill({required String text, required Color color, required Color textColor}) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)), child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)));
  }
}

class _NavigationBanner extends StatelessWidget {
  const _NavigationBanner({required this.directions, required this.stepIndex, required this.onTap});

  final DirectionsResult? directions;
  final int stepIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final steps = directions?.steps ?? const [];
    final step = stepIndex < steps.length ? steps[stepIndex] : null;

    final text = step?.instruction.isNotEmpty == true ? step!.instruction : 'Continue';
    final metaParts = <String>[];
    if (step?.distanceText.isNotEmpty == true) {
      metaParts.add(step!.distanceText);
    }
    if (step?.durationText.isNotEmpty == true) {
      metaParts.add(step!.durationText);
    }

    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(14),
      // I removed the InkWell here so the user specifically has to press the Stop button
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.navigation, color: Color(0xFF2F5CE5)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  if (metaParts.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      metaParts.join(' • '),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6F6F6F)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),

            // --- NEW BLUE STOP BUTTON ---
            GestureDetector(
              onTap: onTap, // This triggers the _stopInAppNavigation function
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF2F5CE5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.stop,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}