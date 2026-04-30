import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_address_page.dart';
import 'address_alarms_page.dart';
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
  List<Map<String, dynamic>> _savedLocations = [];
  Map<String, RouteMonitorConfig> _routeConfigs = {};

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final int? userId = prefs.getInt('user_id');

      if (userId == null) {
        setState(() {
          _savedLocations = [];
          _isLoading = false;
        });
        return;
      }

      // Fetch Addresses
      final addressData = await supabase.from('addressDB').select().eq('user_id', userId);
      // Fetch Tracked Routes
      final routeData = await supabase.from('routedb').select().eq('user_id', userId);

      List<Map<String, dynamic>> combined = [];

      for (var row in addressData) {
        combined.add({
          'id': row['address_id'],
          'type': 'address',
          'label': row['label'] ?? 'Unknown',
          'address': row['address'] ?? '',
          'created_at': row['created_at'],
        });
      }

      for (var row in routeData) {
        final routeName = row['route_name'];
        final label = (routeName != null && routeName.toString().trim().isNotEmpty) ? routeName.toString() : 'Personal Route';

        combined.add({
          'id': row['route_id'],
          'type': 'route',
          'label': label,
          'address': 'Custom Tracked Route',
          'created_at': row['created_at'],
        });
      }

      // Sort both combined lists by date created
      combined.sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateA.compareTo(dateB); // Oldest first
      });

      setState(() {
        _savedLocations = combined;
      });

      final existingConfigs = await RouteMonitorStore.loadAll();
      var updated = false;
      for (final row in _savedLocations) {
        final label = (row['label'] ?? '').toString();
        if (label.isEmpty) continue;
        if (!existingConfigs.containsKey(label)) {
          existingConfigs[label] = RouteMonitorConfig.defaultConfig();
          updated = true;
        }
      }
      if (updated) await RouteMonitorStore.saveAll(existingConfigs);
      _routeConfigs = existingConfigs;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load locations: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteItem(int id, String type) async {
    try {
      if (type == 'address') {
        await supabase.from('addressDB').delete().eq('address_id', id);
      } else {
        await supabase.from('routedb').delete().eq('route_id', id);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item deleted')));
      await _loadLocations();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> row) async {
    final isRoute = row['type'] == 'route';
    final labelController = TextEditingController(text: row['label'] ?? '');
    final addressController = TextEditingController(text: row['address'] ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isRoute ? 'Edit Route Name' : 'Edit Address'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: InputDecoration(labelText: isRoute ? 'Route Name' : 'Label'),
              ),
              if (!isRoute) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
              ]
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

              if (newLabel.isEmpty || (!isRoute && newAddress.isEmpty)) return;

              try {
                if (isRoute) {
                  await supabase.from('routedb').update({'route_name': newLabel}).eq('route_id', row['id']);
                } else {
                  await supabase.from('addressDB').update({'label': newLabel, 'address': newAddress}).eq('address_id', row['id']);
                }

                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated successfully')));
                await _loadLocations();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddressMenu(Map<String, dynamic> row, Offset position) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
      ],
    );

    if (selected == 'edit') {
      await _showEditDialog(row);
    } else if (selected == 'delete') {
      await _deleteItem(row['id'], row['type']);
    }
  }

  IconData _iconForLabel(String label, String type) {
    if (type == 'route') return Icons.route;

    switch (label.toLowerCase()) {
      case 'home': return Icons.home_rounded;
      case 'work': return Icons.work_rounded;
      case 'school': return Icons.edit_rounded;
      case 'gym': return Icons.fitness_center_rounded;
      default: return Icons.location_on_rounded;
    }
  }

  Color _iconColorForLabel(String label, String type) {
    if (type == 'route') return const Color(0xFF673AB7); // Distinct purple color for custom routes

    switch (label.toLowerCase()) {
      case 'home': return const Color(0xFFE53935);
      case 'work': return const Color(0xFF1A3ED4);
      case 'school': return const Color(0xFFD4860A);
      case 'gym': return const Color(0xFF1FCC00);
      default: return const Color(0xFF00BCD4);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A6FD4),
        foregroundColor: Colors.white,
        title: const Text('My Locations', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddAddressPage()),
            ).then((_) => _loadLocations());
          },
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Add Address'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A6FD4),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedLocations.isEmpty
          ? const Center(child: Text('No saved locations yet.', style: TextStyle(fontSize: 16)))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _savedLocations.length,
        itemBuilder: (context, index) {
          final row = _savedLocations[index];
          final label = (row['label'] ?? '').toString();
          final type = row['type'];

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: _iconColorForLabel(label, type), shape: BoxShape.circle),
                    child: Icon(_iconForLabel(label, type), color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 6),
                        Text(row['address'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddressAlarmsPage(
                                    addressId: type == 'address' ? row['id'] : null,
                                    routeId: type == 'route' ? row['id'] : null,
                                    addressLabel: label,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.alarm_add, size: 16),
                            label: const Text('Set Time'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF2F6FF),
                              foregroundColor: const Color(0xFF1A6FD4),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value ? 'Alerts enabled for $label' : 'Alerts disabled for $label')));
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(_routeConfigs[label]?.enabled == true ? 'Alerts: On' : 'Alerts: Off', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
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
                                  await _loadLocations();
                                }
                              }
                            } else {
                              snack.showSnackBar(SnackBar(content: Text(message)));
                            }
                          }
                        },
                      ),
                      GestureDetector(
                        onTapDown: (details) {
                          _showAddressMenu(row, details.globalPosition);
                        },
                        child: const Padding(padding: EdgeInsets.only(left: 8, top: 4), child: Icon(Icons.more_horiz)),
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