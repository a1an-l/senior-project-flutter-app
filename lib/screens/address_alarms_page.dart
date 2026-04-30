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
  List<Map<String, dynamic>> _alarms = [];

  final List<String> _weekDays = ['M', 'T', 'W', 'Th', 'F', 'Sa', 'Su'];

  @override
  void initState() {
    super.initState();
    _loadAlarms();
  }

  Future<void> _loadAlarms() async {
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
        _alarms = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading times: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAlarm(int timeId) async {
    try {
      await supabase.from('time').delete().eq('time_id', timeId);
      await _loadAlarms();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Time removed')));
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

  void _showAddAlarmModal() {
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    List<String> selectedDays = [];

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
                const Text('Set New Time', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
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
                          final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
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
                          if (selected) selectedDays.add(day);
                          else selectedDays.remove(day);
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
                      await supabase.from('time').insert({
                        if (widget.addressId != null) 'address_id': widget.addressId,
                        if (widget.routeId != null) 'route_id': widget.routeId,
                        'start_time': startFormatted,
                        'end_time': endFormatted,
                        'days_repeating': selectedDays,
                      });

                      if (mounted) {
                        Navigator.pop(context);
                        _loadAlarms();
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
                    }
                  },
                  child: const Text('Save Alarm'),
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
        title: Text('${widget.addressLabel} Alarms', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAlarmModal,
        backgroundColor: const Color(0xFF1A6FD4),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alarms.isEmpty
          ? const Center(child: Text('No alarms set for this location yet.'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _alarms.length,
        itemBuilder: (context, index) {
          final alarm = _alarms[index];
          final days = List<String>.from(alarm['days_repeating'] ?? []);
          final daysText = days.isEmpty ? 'Does not repeat' : days.join(', ');

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(
                '${_formatDbTime(alarm['start_time'])} - ${_formatDbTime(alarm['end_time'])}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Text('Days: $daysText', style: const TextStyle(color: Colors.black54)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteAlarm(alarm['time_id']),
              ),
            ),
          );
        },
      ),
    );
  }
}