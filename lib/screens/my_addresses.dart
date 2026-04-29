import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_address_page.dart';
import '../services/route_monitor_store.dart';
import '../services/route_traffic_service.dart';


class MyAddresses extends StatefulWidget {
  const MyAddresses({super.key});

  @override
  State<MyAddresses> createState() => _MyAddressesPageState();
}

class _MyAddressesPageState extends State<MyAddresses> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<Map<String, dynamic>> _addresses = [];
  Map<String, RouteMonitorConfig> _routeConfigs = {};

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final int? userId = prefs.getInt('user_id');

      if (userId == null) {
        setState(() {
          _addresses = [];
          _isLoading = false;
        });
        return;
      }

      final data = await supabase
          .from('addressDB')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      setState(() {
        _addresses = List<Map<String, dynamic>>.from(data);
      });

      // Ensure route monitor configs exist for each label, and sync DB times when available
      final existingConfigs = await RouteMonitorStore.loadAll();
      var updated = false;
      for (final row in _addresses) {
        final label = (row['label'] ?? '').toString();
        if (label.isEmpty) continue;
        if (!existingConfigs.containsKey(label)) {
          final start = _parseTime(row['start_time']);
          final end = _parseTime(row['end_time']);
          final cfg = (start != null && end != null)
              ? RouteMonitorConfig(
                  enabled: true,
                  startHour: start.hour,
                  startMinute: start.minute,
                  endHour: end.hour,
                  endMinute: end.minute,
                  autoResetBaseline: false,
                  autoResetIntervalMinutes: 24 * 60,
                  lastResetAtMs: 0,
                )
              : RouteMonitorConfig.defaultConfig();
          existingConfigs[label] = cfg;
          updated = true;
        }
      }
      if (updated) await RouteMonitorStore.saveAll(existingConfigs);
      _routeConfigs = existingConfigs;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load addresses: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAddress(int addressId) async {
    try {
      await supabase
          .from('addressDB')
          .delete()
          .eq('address_id', addressId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address deleted')),
      );

      await _loadAddresses();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete address: $e')),
      );
    }
  }

  TimeOfDay? _parseTime(dynamic value) {
    if (value == null) return null;
    final text = value.toString();
    final parts = text.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String? _timeToDbString(TimeOfDay? time) {
    if (time == null) return null;
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  String _formatTimeRange(dynamic start, dynamic end) {
    final startTime = _parseTime(start);
    final endTime = _parseTime(end);

    if (startTime == null || endTime == null) {
      return 'No alert window set';
    }

    return '${startTime.format(context)} - ${endTime.format(context)}';
  }

  Future<void> _showEditDialog(Map<String, dynamic> addressRow) async {
    final labelController =
        TextEditingController(text: addressRow['label'] ?? '');
    final addressController =
        TextEditingController(text: addressRow['address'] ?? '');

    TimeOfDay? startTime = _parseTime(addressRow['start_time']);
    TimeOfDay? endTime = _parseTime(addressRow['end_time']);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Address'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(labelText: 'Label'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 16),
                Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: startTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => startTime = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule,
                                color: Color(0xFF1A6FD4)),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Start Time',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              startTime == null
                                  ? 'Select'
                                  : startTime!.format(context),
                              style: TextStyle(
                                fontSize: 14,
                                color: startTime == null
                                    ? Colors.black45
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: endTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => endTime = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule,
                                color: Color(0xFF1A6FD4)),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'End Time',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              endTime == null
                                  ? 'Select'
                                  : endTime!.format(context),
                              style: TextStyle(
                                fontSize: 14,
                                color: endTime == null
                                    ? Colors.black45
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newLabel = labelController.text.trim();
                final newAddress = addressController.text.trim();

                if (newLabel.isEmpty || newAddress.isEmpty) return;

                try {
                  await supabase
                      .from('addressDB')
                      .update({
                        'label': newLabel,
                        'address': newAddress,
                        'start_time': _timeToDbString(startTime),
                        'end_time': _timeToDbString(endTime),
                      })
                      .eq('address_id', addressRow['address_id']);

                  if (!mounted) return;
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Address updated')),
                  );

                  await _loadAddresses();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update address: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddressMenu(Map<String, dynamic> addressRow, Offset position) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: const [
        PopupMenuItem(
          value: 'edit',
          child: Text('Edit'),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text(
            'Delete',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    );

    if (selected == 'edit') {
      await _showEditDialog(addressRow);
    } else if (selected == 'delete') {
      await _deleteAddress(addressRow['address_id']);
    }
  }

  IconData _iconForLabel(String label) {
  switch (label.toLowerCase()) {
    case 'home':
      return Icons.home_rounded;
    case 'work':
      return Icons.work_rounded;
    case 'school':
      return Icons.edit_rounded;
    case 'gym':
      return Icons.fitness_center_rounded;
    default:
      return Icons.location_on_rounded;
  }
}

  Color _iconColorForLabel(String label) {
  switch (label.toLowerCase()) {
    case 'home':
      return const Color(0xFFE53935);
    case 'work':
      return const Color(0xFF1A3ED4);
    case 'school':
      return const Color(0xFFD4860A);
    case 'gym':
      return const Color(0xFF1FCC00);
    default:
      return const Color(0xFF00BCD4);
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
          'My Addresses',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AddAddressPage(),
              ),
            ).then((_) => _loadAddresses());
          },
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Add Address'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A6FD4),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
              ? const Center(
                  child: Text(
                    'No saved addresses yet.',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _addresses.length,
                  itemBuilder: (context, index) {
                    final row = _addresses[index];
                    final label = (row['label'] ?? '').toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: _iconColorForLabel(label),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _iconForLabel(label),
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    row['address'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF2F6FF),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Alerts: ${_formatTimeRange(row['start_time'], row['end_time'])}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1A6FD4),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Switch(
                                  value: _routeConfigs[label]?.enabled ?? false,
                                  onChanged: (value) async {
                                    final current = _routeConfigs[label] ?? RouteMonitorConfig.defaultConfig();
                                    final updated = RouteMonitorConfig(
                                      enabled: value,
                                      startHour: current.startHour,
                                      startMinute: current.startMinute,
                                      endHour: current.endHour,
                                      endMinute: current.endMinute,
                                      autoResetBaseline: current.autoResetBaseline,
                                      autoResetIntervalMinutes: current.autoResetIntervalMinutes,
                                      lastResetAtMs: current.lastResetAtMs,
                                    );
                                    await RouteMonitorStore.save(label, updated);
                                    setState(() => _routeConfigs[label] = updated);
                                    await RouteTrafficService.refreshMonitoring();

                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(value ? 'Alerts enabled for $label' : 'Alerts disabled for $label'),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _routeConfigs[label]?.enabled == true ? 'Alerts: On' : 'Alerts: Off',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.play_arrow),
                                  tooltip: 'Test route alerts',
                                  onPressed: () async {
                                    final snack = ScaffoldMessenger.of(context);
                                    snack.showSnackBar(const SnackBar(content: Text('Testing route...')));
                                    final result = await RouteTrafficService.testRoute(label);
                                    final message = result['message']?.toString() ?? 'Test complete';
                                    if (mounted) {
                                      snack.hideCurrentSnackBar();
                                      // If message indicates missing historical average, offer to seed baseline
                                      if (message.toLowerCase().contains('no historical average')) {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('No baseline'),
                                            content: Text('$message\n\nWould you like to seed a baseline using your current travel time?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Seed baseline')),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          snack.showSnackBar(const SnackBar(content: Text('Seeding baseline...')));
                                          final seedRes = await RouteTrafficService.seedBaseline(label);
                                          final seedMsg = seedRes['message']?.toString() ?? 'Seed complete';
                                          if (mounted) {
                                            snack.hideCurrentSnackBar();
                                            snack.showSnackBar(SnackBar(content: Text(seedMsg)));
                                            await _loadAddresses();
                                          }
                                        }
                                      } else {
                                        snack.showSnackBar(SnackBar(content: Text(message)));
                                      }
                                    }
                                  },
                                ),
                                // Auto-reset baseline is now automatic every 15 minutes; UI option removed.
                                
                                GestureDetector(
                                  onTapDown: (details) {
                                    _showAddressMenu(row, details.globalPosition);
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.only(left: 8, top: 4),
                                    child: Icon(Icons.more_horiz),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}