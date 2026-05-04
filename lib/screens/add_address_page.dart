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

  final List<Map<String, dynamic>> _pendingAlarms = [];
  final List<String> _weekDays = ['M', 'T', 'W', 'Th', 'F', 'Sa', 'Su'];

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

  void _showAddAlarmModal() {
    final theme = Theme.of(context);
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    List<String> selectedDays = [];

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Set Schedule',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (picked != null) {
                            setModalState(() => startTime = picked);
                          }
                        },
                        icon: Icon(
                          Icons.access_time,
                          color: theme.colorScheme.primary,
                        ),
                        label: Text(
                          startTime?.format(context) ?? 'Start Time',
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (picked != null) {
                            setModalState(() => endTime = picked);
                          }
                        },
                        icon: Icon(
                          Icons.access_time_filled,
                          color: theme.colorScheme.primary,
                        ),
                        label: Text(
                          endTime?.format(context) ?? 'End Time',
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Repeat on',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: _weekDays.map((day) {
                    final isSelected = selectedDays.contains(day);
                    return ChoiceChip(
                      label: Text(day),
                      selected: isSelected,
                      selectedColor:
                          theme.colorScheme.primary.withOpacity(0.2),
                      onSelected: (selected) {
                        setModalState(() {
                          if (selected) {
                            selectedDays.add(day);
                          } else {
                            selectedDays.remove(day);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    if (startTime == null || endTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select start and end times'),
                        ),
                      );
                      return;
                    }

                    final startFormatted =
                        '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}:00';
                    final endFormatted =
                        '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}:00';

                    setState(() {
                      _pendingAlarms.add({
                        'start_time': startFormatted,
                        'end_time': endFormatted,
                        'days_repeating': List<String>.from(selectedDays),
                      });
                    });

                    Navigator.pop(context);
                  },
                  child: const Text('Add to Schedule'),
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDbTime(String dbTime) {
    final parts = dbTime.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final time = TimeOfDay(hour: h, minute: m);
      return time.format(context);
    }
    return dbTime;
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
      int targetAddressId;

      final existing = await client
          .from('addressDB')
          .select('address_id')
          .eq('user_id', userId)
          .eq('label', label)
          .maybeSingle();

      if (existing != null) {
        await client
            .from('addressDB')
            .update({'address': address})
            .eq('address_id', existing['address_id']);
        targetAddressId = existing['address_id'];
      } else {
        final insertResponse = await client
            .from('addressDB')
            .insert({
              'user_id': userId,
              'label': label,
              'address': address,
              'created_at': DateTime.now().toIso8601String(),
            })
            .select('address_id')
            .single();

        targetAddressId = insertResponse['address_id'];
      }

      if (_pendingAlarms.isNotEmpty) {
        final alarmsToInsert = _pendingAlarms
            .map((alarm) => {
                  'address_id': targetAddressId,
                  'start_time': alarm['start_time'],
                  'end_time': alarm['end_time'],
                  'days_repeating': alarm['days_repeating'],
                })
            .toList();

        await client.from('time').insert(alarmsToInsert);
      }

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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary,
        foregroundColor:
            theme.appBarTheme.foregroundColor ?? Colors.white,
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
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Label',
                        hintText: 'Home, Work, School...',
                        labelStyle:
                            TextStyle(color: theme.textTheme.bodyMedium?.color),
                        hintStyle:
                            TextStyle(color: theme.textTheme.bodySmall?.color),
                        filled: true,
                        fillColor: theme.cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 10),
                          Icon(
                            Icons.search,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _addressController,
                              focusNode: _addressFocus,
                              style: TextStyle(color: theme.colorScheme.onSurface),
                              decoration: InputDecoration(
                                hintText: 'Search address',
                                hintStyle: TextStyle(
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          if (searching || loadingKey)
                            SizedBox(
                              width: 38,
                              height: 38,
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.primary,
                                ),
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
                              icon: Icon(
                                Icons.close,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.dividerColor.withOpacity(0.4),
                          ),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount:
                              suggestions.length > 6 ? 6 : suggestions.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: theme.dividerColor,
                          ),
                          itemBuilder: (context, index) {
                            final item = suggestions[index];
                            return ListTile(
                              title: Text(
                                item.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              onTap: () => _selectSuggestion(item),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Schedules',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showAddAlarmModal,
                          icon: Icon(
                            Icons.add,
                            color: theme.colorScheme.primary,
                          ),
                          label: Text(
                            'Add Time',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_pendingAlarms.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Text(
                          'No schedules added yet.',
                          style: TextStyle(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ..._pendingAlarms.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final alarm = entry.value;
                        final days = List<String>.from(
                          alarm['days_repeating'] ?? [],
                        );
                        final daysText =
                            days.isEmpty ? 'Does not repeat' : days.join(', ');

                        return Card(
                          color: theme.cardColor,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: Text(
                              '${_formatDbTime(alarm['start_time'])} - ${_formatDbTime(alarm['end_time'])}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              'Days: $daysText',
                              style: TextStyle(
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                setState(() {
                                  _pendingAlarms.removeAt(idx);
                                });
                              },
                            ),
                          ),
                        );
                      }),
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
                    backgroundColor: theme.colorScheme.primary,
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