import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/history_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final HistoryService _historyService = HistoryService();

  List<Map<String, dynamic>> _historyItems = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserHistory();
  }

  Future<void> _loadUserHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Find out who is logged in
      final prefs = await SharedPreferences.getInstance();
      final int? currentUserId = prefs.getInt('user_id');

      if (currentUserId == null) {
        setState(() {
          _errorMessage = "You must be logged in to view your history.";
          _isLoading = false;
        });
        return;
      }

      // 2. Fetch their data from Supabase
      final data = await _historyService.getUserHistory(currentUserId);

      setState(() {
        _historyItems = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to load history.";
        _isLoading = false;
      });
    }
  }

  // Helper function to format the complicated database timestamp into a readable date
  String _formatDate(String timestamp) {
    try {
      final DateTime date = DateTime.parse(timestamp).toLocal();
      return "${date.month}/${date.day}/${date.year} at ${date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour)}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}";
    } catch (e) {
      return "Unknown Date";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2F5CE5),
        foregroundColor: Colors.white,
        title: const Text('Navigation History', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2F5CE5)));
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16)),
      );
    }

    if (_historyItems.isEmpty) {
      return const Center(
        child: Text("You haven't navigated anywhere yet!", style: TextStyle(fontSize: 16, color: Colors.grey)),
      );
    }

    // Displays the list of history items
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _historyItems.length,
      itemBuilder: (context, index) {
        final item = _historyItems[index];
        final destination = item['dst_address'] ?? 'Unknown Destination';
        final start = item['Start_add'] ?? 'Unknown Start';
        final date = item['timestamp'] != null ? _formatDate(item['timestamp']) : 'Unknown Date';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFFE53935), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        destination,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                Row(
                  children: [
                    const Icon(Icons.my_location, color: Colors.grey, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "From: $start",
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.grey, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      date,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}