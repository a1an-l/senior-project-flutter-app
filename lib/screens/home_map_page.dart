import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'location_input_page.dart';

import '../services/api_keys.dart';
import '../services/google_places_directions_service.dart';

class HomeMapPage extends StatefulWidget {
  const HomeMapPage({super.key});

  @override
  State<HomeMapPage> createState() => _HomeMapPageState();
}

class _HomeMapPageState extends State<HomeMapPage> {
  int bottomIndex = 0;
  GoogleMapController? controller;
  bool myLocationEnabled = false;
  Position? currentPosition;
  StreamSubscription<Position>? positionSubscription;
  bool followUser = true;
  String? googleMapsWebApiKey;

  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  List<PlaceSuggestion> suggestions = [];
  bool searching = false;
  PlaceDetails? selectedPlace;
  String sessionToken = DateTime.now().millisecondsSinceEpoch.toString();

  Set<Marker> markers = {};
  Set<Polyline> polylines = {};

  static const CameraPosition initialCameraPosition = CameraPosition(
    target: LatLng(26.3017, -98.1633),
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadWebKey();
    searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadWebKey() async {
    final key = await ApiKeys.googleMapsWebApiKey();
    if (!mounted) {
      return;
    }
    setState(() => googleMapsWebApiKey = key);
  }

  @override
  void dispose() {
    positionSubscription?.cancel();
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  GooglePlacesDirectionsService? get googleService {
    final apiKey = googleMapsWebApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }
    return GooglePlacesDirectionsService(apiKey: apiKey);
  }

  Future<void> _initLocation() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() => myLocationEnabled = true);

    final Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    currentPosition = position;

    positionSubscription?.cancel();
    positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      ),
    ).listen((p) async {
      currentPosition = p;
      if (!mounted) {
        return;
      }
      if (followUser && controller != null) {
        await controller!.animateCamera(
          CameraUpdate.newLatLng(LatLng(p.latitude, p.longitude)),
        );
      }
    });

    if (!mounted) {
      return;
    }

    final GoogleMapController? currentController = controller;
    if (currentController == null) {
      return;
    }

    await currentController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 15,
        ),
      ),
    );
  }

  Future<void> _onSearchChanged() async {
    final text = searchController.text.trim();
    if (!searchFocusNode.hasFocus) {
      return;
    }
    if (text.isEmpty) {
      if (mounted) {
        setState(() => suggestions = []);
      }
      return;
    }

    final service = googleService;
    if (service == null) {
      return;
    }

    setState(() => searching = true);
    final results = await service.autocomplete(input: text, sessionToken: sessionToken);
    if (!mounted) {
      return;
    }
    setState(() {
      suggestions = results;
      searching = false;
    });
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    final service = googleService;
    if (service == null) {
      return;
    }
    final origin = currentPosition;
    if (origin == null) {
      return;
    }

    searchFocusNode.unfocus();
    setState(() {
      suggestions = [];
      searching = true;
      selectedPlace = null;
      polylines = {};
      markers = {};
    });

    final details = await service.placeDetails(
      placeId: suggestion.placeId,
      sessionToken: sessionToken,
    );
    if (!mounted || details == null) {
      return;
    }

    final directions = await service.directions(
      originLat: origin.latitude,
      originLng: origin.longitude,
      destLat: details.lat,
      destLng: details.lng,
    );

    if (!mounted) {
      return;
    }

    final destLatLng = LatLng(details.lat, details.lng);
    final newMarkers = <Marker>{
      Marker(
        markerId: const MarkerId('destination'),
        position: destLatLng,
        infoWindow: InfoWindow(title: details.name),
      ),
    };

    final newPolylines = <Polyline>{};
    if (directions != null) {
      final points = directions.polylinePoints
          .map((p) => LatLng(p[0], p[1]))
          .toList(growable: false);
      newPolylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          width: 5,
          color: const Color(0xFF2F5CE5),
        ),
      );

      final bounds = _boundsFor(points);
      await controller?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 70),
      );
    } else {
      await controller?.animateCamera(CameraUpdate.newLatLngZoom(destLatLng, 14));
    }

    setState(() {
      selectedPlace = details;
      markers = newMarkers;
      polylines = newPolylines;
      searching = false;
      searchController.text = details.name.isEmpty ? suggestion.description : details.name;
      sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
    });
  }

  LatLngBounds _boundsFor(List<LatLng> points) {
    double? minLat;
    double? maxLat;
    double? minLng;
    double? maxLng;

    for (final p in points) {
      minLat = minLat == null ? p.latitude : (p.latitude < minLat ? p.latitude : minLat);
      maxLat = maxLat == null ? p.latitude : (p.latitude > maxLat ? p.latitude : maxLat);
      minLng = minLng == null ? p.longitude : (p.longitude < minLng ? p.longitude : minLng);
      maxLng = maxLng == null ? p.longitude : (p.longitude > maxLng ? p.longitude : maxLng);
    }

    return LatLngBounds(
      southwest: LatLng(minLat ?? 0, minLng ?? 0),
      northeast: LatLng(maxLat ?? 0, maxLng ?? 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2F5CE5),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {},
        ),
        title: const Text(
          'HiWay',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.notifications_none),
                Positioned(
                  right: -1,
                  top: -1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(width: 8, height: 8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: initialCameraPosition,
            myLocationEnabled: myLocationEnabled,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            markers: markers,
            polylines: polylines,
            onCameraMoveStarted: () => followUser = false,
            onMapCreated: (value) {
              controller = value;
              if (myLocationEnabled) {
                _initLocation();
              }
            },
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
                    _TopChip(
                      label: 'Home',
                      icon: Icons.home_outlined,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LocationInputPage(
                              title: 'Home',
                              placeholder: 'Enter your home address',
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _TopChip(
                      label: 'Work',
                      icon: Icons.work_outline,
                      onPressed: () {},
                    ),
                    const SizedBox(width: 8),
                    _TopChip(
                      label: 'New',
                      icon: Icons.add,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 62, 16, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 10,
                            offset: Offset(0, 6),
                          ),
                        ],
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
                              decoration: const InputDecoration(
                                hintText: 'Search',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (searching)
                            const SizedBox(
                              width: 28,
                              height: 28,
                              child: Padding(
                                padding: EdgeInsets.all(6),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          else if (searchController.text.isNotEmpty)
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  searchController.clear();
                                  suggestions = [];
                                  selectedPlace = null;
                                  polylines = {};
                                  markers = {};
                                });
                              },
                              icon: const Icon(Icons.close, size: 18),
                            ),
                        ],
                      ),
                    ),
                    if (suggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE5E5E5)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 10,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: suggestions.length > 6 ? 6 : suggestions.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final s = suggestions[index];
                            return ListTile(
                              dense: true,
                              title: Text(
                                s.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                              onTap: () => _selectSuggestion(s),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            _BottomItem(
              icon: Icons.map_outlined,
              label: 'Map',
              selected: bottomIndex == 0,
              onPressed: () => setState(() => bottomIndex = 0),
            ),
            const Spacer(),
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Color(0xFF2F5CE5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              ),
            ),
            const Spacer(),
            _BottomItem(
              icon: Icons.history,
              label: 'History',
              selected: bottomIndex == 1,
              onPressed: () => setState(() => bottomIndex = 1),
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
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black87,
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFE5E5E5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 34),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? const Color(0xFF2F5CE5) : const Color(0xFF8A8A8A);

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(64, 48),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}
