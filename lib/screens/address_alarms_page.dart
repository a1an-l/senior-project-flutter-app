import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddressAlarmsPage extends StatefulWidget {
  final int? addressId;
  final int? routeId;
  final String addressLabel;

  const AddressAlarmsPage({
    super.key,
    this.addressId,
    this.routeId,
    required this.addressLabel,
  });

  @override
  State<AddressAlarmsPage> createState() => _AddressAlarmsPageState();
}

class _AddressAlarmsPageState extends State<AddressAlarmsPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _alerts = [];

  final List<String> _weekDays = ['M', 'T', 'W', 'Th', 'F', 'Sa', 'Su'];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    try {
      var query = supabase.from('time').select();

      if (widget.addressId != null) {
        query = query.eq('address_id', widget.addressId!);
      } else if (widget.routeId != null) {
        query = query.eq('route_id', widget.routeId!);
      }

      final data = await query.order('created_at', ascending: true);

      setState(() {
        _alerts = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading alerts: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAlert(int timeId) async {
    try {
      await supabase.from('time').delete().eq('time_id', timeId);
      await _loadAlerts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alert removed')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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

  // Smart modal that handles BOTH adding new alerts and editing existing ones
  void _showAlertModal({Map<String, dynamic>? existingAlert}) {
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    List<String> selectedDays = [];

    // Pre-fill the form if an existing alert was passed in
    if (existingAlert != null) {
      final startParts = existingAlert['start_time'].toString().split(':');
      if (startParts.length >= 2) {
        startTime = TimeOfDay(hour: int.tryParse(startParts[0]) ?? 0, minute: int.tryParse(startParts[1]) ?? 0);
      }

      final endParts = existingAlert['end_time'].toString().split(':');
      if (endParts.length >= 2) {
        endTime = TimeOfDay(hour: int.tryParse(endParts[0]) ?? 0, minute: int.tryParse(endParts[1]) ?? 0);
      }

      selectedDays = List<String>.from(existingAlert['days_repeating'] ?? []);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20, right: 20, top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    existingAlert == null ? 'Set New Alert' : 'Edit Alert',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(context: context, initialTime: startTime ?? TimeOfDay.now());
                          if (picked != null) setModalState(() => startTime = picked);
                        },
                        icon: const Icon(Icons.access_time),
                        label: Text(startTime?.format(context) ?? 'Start Time'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(context: context, initialTime: endTime ?? TimeOfDay.now());
                          if (picked != null) setModalState(() => endTime = picked);
                        },
                        icon: const Icon(Icons.access_time_filled),
                        label: Text(endTime?.format(context) ?? 'End Time'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Repeat on', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: _weekDays.map((day) {
                    final isSelected = selectedDays.contains(day);
                    return ChoiceChip(
                      label: Text(day),
                      selected: isSelected,
                      selectedColor: const Color(0xFF1A6FD4).withOpacity(0.2),
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
                    backgroundColor: const Color(0xFF1A6FD4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    if (startTime == null || endTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select start and end times')));
                      return;
                    }

                    final startFormatted = '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}:00';
                    final endFormatted = '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}:00';

                    try {
                      if (existingAlert == null) {
                        // Creating a brand new alert
                        await supabase.from('time').insert({
                          if (widget.addressId != null) 'address_id': widget.addressId,
                          if (widget.routeId != null) 'route_id': widget.routeId,
                          'start_time': startFormatted,
                          'end_time': endFormatted,
                          'days_repeating': selectedDays,
                        });
                      } else {
                        // Updating an existing alert
                        await supabase.from('time').update({
                          'start_time': startFormatted,
                          'end_time': endFormatted,
                          'days_repeating': selectedDays,
                        }).eq('time_id', existingAlert['time_id']);
                      }

                      if (mounted) {
                        Navigator.pop(context);
                        _loadAlerts(); // Refresh the list
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
                    }
                  },
                  child: Text(existingAlert == null ? 'Save Alert' : 'Update Alert'),
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A6FD4),
        foregroundColor: Colors.white,
        title: Text('${widget.addressLabel} Alerts', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAlertModal(), // Passing nothing means it's a "New" alert
        backgroundColor: const Color(0xFF1A6FD4),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alerts.isEmpty
          ? const Center(child: Text('No alerts set for this location yet.'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _alerts.length,
        itemBuilder: (context, index) {
          final alert = _alerts[index];
          final days = List<String>.from(alert['days_repeating'] ?? []);
          final daysText = days.isEmpty ? 'Does not repeat' : days.join(', ');

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(
                '${_formatDbTime(alert['start_time'])} - ${_formatDbTime(alert['end_time'])}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Text('Days: $daysText', style: const TextStyle(color: Colors.black54)),

              // Added a Row to hold both Edit and Delete buttons
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                    onPressed: () => _showAlertModal(existingAlert: alert), // Pass the existing alert to edit
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteAlert(alert['time_id']),
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