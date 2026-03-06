import 'package:flutter/material.dart';

import '../services/api_keys.dart';
import '../services/google_places_directions_service.dart';
import '../services/saved_places.dart';

class LocationInputPage extends StatefulWidget {
  final String title;
  final String placeholder;

  const LocationInputPage({
    super.key,
    required this.title,
    required this.placeholder,
  });

  @override
  State<LocationInputPage> createState() => _LocationInputPageState();
}

class _LocationInputPageState extends State<LocationInputPage> {
  final TextEditingController addressController = TextEditingController();
  final FocusNode addressFocus = FocusNode();

  String? mapsApiKey;
  bool loadingKey = true;
  bool searching = false;
  List<PlaceSuggestion> suggestions = [];
  String sessionToken = DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    _loadKey();
    addressController.addListener(_onChanged);
  }

  @override
  void dispose() {
    addressController.dispose();
    addressFocus.dispose();
    super.dispose();
  }

  Future<void> _loadKey() async {
    final key = await ApiKeys.mapsApiKey();
    if (!mounted) {
      return;
    }
    setState(() {
      mapsApiKey = key;
      loadingKey = false;
    });
  }

  GooglePlacesDirectionsService? get service {
    final key = mapsApiKey;
    if (key == null || key.isEmpty) {
      return null;
    }
    return GooglePlacesDirectionsService(apiKey: key);
  }

  Future<void> _onChanged() async {
    if (!addressFocus.hasFocus) {
      return;
    }
    final text = addressController.text.trim();
    if (text.isEmpty) {
      if (mounted) {
        setState(() => suggestions = []);
      }
      return;
    }

    final s = service;
    if (s == null) {
      return;
    }

    setState(() => searching = true);
    final results = await s.autocomplete(input: text, sessionToken: sessionToken);
    if (!mounted) {
      return;
    }
    setState(() {
      suggestions = results;
      searching = false;
    });
  }

  Future<void> _select(PlaceSuggestion suggestion) async {
    final s = service;
    if (s == null) {
      return;
    }

    setState(() {
      searching = true;
      suggestions = [];
    });

    final details = await s.placeDetails(
      placeId: suggestion.placeId,
      sessionToken: sessionToken,
    );

    if (!mounted || details == null) {
      return;
    }

    final saved = SavedPlace(
      label: widget.title,
      name: details.name.isEmpty ? suggestion.description : details.name,
      address: details.formattedAddress.isEmpty ? suggestion.description : details.formattedAddress,
      lat: details.lat,
      lng: details.lng,
      placeId: details.placeId,
    );

    await SavedPlacesStore.set(saved);

    if (!mounted) {
      return;
    }

    setState(() {
      searching = false;
      sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
    });

    Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A6FD4),
              Color(0xFF2196F3),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 6),
                      const Icon(Icons.search, color: Color(0xFFAAAAAA)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: addressController,
                          focusNode: addressFocus,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: widget.placeholder,
                            hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      if (searching || loadingKey)
                        const SizedBox(
                          width: 38,
                          height: 38,
                          child: Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (addressController.text.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            setState(() {
                              addressController.clear();
                              suggestions = [];
                            });
                          },
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: suggestions.isEmpty
                      ? const SizedBox.shrink()
                      : ListView.separated(
                          itemCount: suggestions.length > 8 ? 8 : suggestions.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = suggestions[index];
                            return ListTile(
                              title: Text(
                                item.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _select(item),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
