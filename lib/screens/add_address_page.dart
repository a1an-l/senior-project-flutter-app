import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api_keys.dart';
import '../services/google_places_directions_service.dart';
import '../services/route_traffic_service.dart';

class AddAddressPage extends StatefulWidget {
  const AddAddressPage({super.key});

  @override
  State<AddAddressPage> createState() => _AddAddressPageState();
}

class _AddAddressPageState extends State<AddAddressPage> {
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final FocusNode _addressFocus = FocusNode();

  String? mapsApiKey;
  bool loadingKey = true;
  bool searching = false;
  bool saving = false;

  List<PlaceSuggestion> suggestions = [];
  String sessionToken = DateTime.now().millisecondsSinceEpoch.toString();

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _loadKey();
    _addressController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  Future<void> _loadKey() async {
    final key = await ApiKeys.mapsApiKey();
    if (!mounted) return;

    setState(() {
      mapsApiKey = key;
      loadingKey = false;
    });
  }

  GooglePlacesDirectionsService? get service {
    final key = mapsApiKey;
    if (key == null || key.isEmpty) return null;
    return GooglePlacesDirectionsService(apiKey: key);
  }

  Future<void> _onChanged() async {
    if (!_addressFocus.hasFocus) return;

    final text = _addressController.text.trim();
    if (text.isEmpty) {
      if (mounted) setState(() => suggestions = []);
      return;
    }

    final s = service;
    if (s == null) return;

    setState(() => searching = true);

    try {
      final results = await s.autocomplete(
        input: text,
        sessionToken: sessionToken,
      );

      if (!mounted) return;
      setState(() {
        suggestions = results;
        searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => searching = false);
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    final s = service;
    if (s == null) return;

    setState(() {
      searching = true;
      suggestions = [];
    });

    final details = await s.placeDetails(
      placeId: suggestion.placeId,
      sessionToken: sessionToken,
    );

    if (!mounted || details == null) return;

    setState(() {
      _addressController.text = details.formattedAddress.isEmpty
          ? suggestion.description
          : details.formattedAddress;
      searching = false;
      sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
    });

    _addressFocus.unfocus();
  }

  String? _timeToDbString(TimeOfDay? time) {
    if (time == null) return null;
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  Widget _buildTimeRow({
    required String label,
    required TimeOfDay? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule, color: Color(0xFF1A6FD4)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value == null ? 'Select' : value.format(context),
              style: TextStyle(
                fontSize: 14,
                color: value == null ? Colors.black45 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAddress() async {
    final label = _labelController.text.trim();
    final address = _addressController.text.trim();

    if (label.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Label and address are required.')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final int? userId = prefs.getInt('user_id');

      if (userId == null) {
        throw Exception('No logged in user found.');
      }

      final client = Supabase.instance.client;

      final existing = await client
          .from('addressDB')
          .select('address_id')
          .eq('user_id', userId)
          .eq('label', label)
          .maybeSingle();

      if (existing != null) {
        await client
            .from('addressDB')
            .update({
              'address': address,
              'start_time': _timeToDbString(_startTime),
              'end_time': _timeToDbString(_endTime),
            })
            .eq('address_id', existing['address_id']);
      } else {
        await client.from('addressDB').insert({
          'user_id': userId,
          'label': label,
          'address': address,
          'start_time': _timeToDbString(_startTime),
          'end_time': _timeToDbString(_endTime),
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Best-effort: automatically seed a baseline for this route in background.
      // We don't await this to avoid blocking the UI; failures are non-fatal.
      RouteTrafficService.seedBaseline(label).then((_) {}).catchError((_) {});

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save address: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A6FD4),
        foregroundColor: Colors.white,
        title: const Text(
          'Add Address',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(
                      controller: _labelController,
                      decoration: InputDecoration(
                        labelText: 'Label',
                        hintText: 'Home, Work, School...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 10),
                          const Icon(Icons.search, color: Color(0xFFAAAAAA)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _addressController,
                              focusNode: _addressFocus,
                              decoration: const InputDecoration(
                                hintText: 'Search address',
                                border: InputBorder.none,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 14),
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
                          else if (_addressController.text.isNotEmpty)
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _addressController.clear();
                                  suggestions = [];
                                });
                              },
                              icon: const Icon(Icons.close),
                            ),
                        ],
                      ),
                    ),
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: suggestions.length > 6 ? 6 : suggestions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = suggestions[index];
                            return ListTile(
                              title: Text(
                                item.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _selectSuggestion(item),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildTimeRow(
                      label: 'Start Time',
                      value: _startTime,
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _startTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() => _startTime = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTimeRow(
                      label: 'End Time',
                      value: _endTime,
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _endTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() => _endTime = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              minimum: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saving ? null : _saveAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A6FD4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'SAVE ADDRESS',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}