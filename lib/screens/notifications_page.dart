import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notifications_store.dart';
import '../services/supabase_notifications_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<HiWayNotification> items = [];
  bool loading = true;
  bool isGuest = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Check if user is logged in
    final prefs = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('user_id');

    if (userId == null) {
      // User is a guest
      if (!mounted) return;
      setState(() {
        isGuest = true;
        loading = false;
      });
      return;
    }

    final list = await NotificationsStore.list();
    await NotificationsStore.markAllRead();
    if (!mounted) {
      return;
    }
    setState(() {
      items = list;
      isGuest = false;
      loading = false;
    });
  }

  Future<void> _clearAll() async {
    await NotificationsStore.clearAll();
    // Also clear in Supabase
    await SupabaseNotificationsService().clearAllAlerts();
    if (!mounted) {
      return;
    }
    setState(() => items = []);
  }

  String _formatTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'pm' : 'am';
    return '$h:$m $suffix';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2F5CE5),
        foregroundColor: Colors.white,
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : isGuest
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Log in to view notifications',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to your account to start receiving traffic alerts and notifications.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        itemCount: items.length,
                        separatorBuilder: (context, index) => const Divider(height: 18),
                        itemBuilder: (context, index) {
                          final n = items[index];
                          return _NotificationRow(
                            title: n.title,
                            subtitle: n.subtitle,
                            detail: n.detail,
                            timeText: _formatTime(n.createdAtMs),
                            urgent: n.urgent,
                          );
                        },
                      ),
                    ),
                    TextButton(
                      onPressed: _clearAll,
                      child: const Text(
                        'Clear All',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.timeText,
    required this.urgent,
  });

  final String title;
  final String subtitle;
  final String detail;
  final String timeText;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    timeText,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6F6F6F)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6F6F6F)),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: TextStyle(
                  fontSize: 12,
                  color: urgent ? const Color(0xFFC62828) : const Color(0xFF2F5CE5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

