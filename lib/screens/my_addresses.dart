import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_address_page.dart';
import 'address_alarms_page.dart'; // NEW IMPORT
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

      final existingConfigs = await RouteMonitorStore.loadAll();
      var updated = false;
      for (final row in _addresses) {
        final label = (row['label'] ?? '').toString();
        if (label.isEmpty) continue;
        if (!existingConfigs.containsKey(label)) {
          // Initialize with default config since times are now managed in time table
          existingConfigs[label] = RouteMonitorConfig.defaultConfig();
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

  Future<void> _showEditDialog(Map<String, dynamic> addressRow) async {
    final labelController =
    TextEditingController(text: addressRow['label'] ?? '');
    final addressController =
    TextEditingController(text: addressRow['address'] ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                // Update only label and address
                await supabase
                    .from('addressDB')
                    .update({
                  'label': newLabel,
                  'address': newAddress,
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
                        // --- NEW SET TIME BUTTON ---
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddressAlarmsPage(
                                    addressId: row['address_id'],
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
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