import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = false;
  bool _darkMapEnabled = false;

  String _locationPermissionStatus = 'Checking...';
  String _notificationPermissionStatus = 'Checking...';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadPermissionStatuses();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _darkMapEnabled = prefs.getBool('dark_map_enabled') ?? false;
    });
  }

  Future<void> _loadPermissionStatuses() async {
    final locationPermission = await Geolocator.checkPermission();
    final notificationPermission = await Permission.notification.status;

    if (!mounted) return;

    setState(() {
      _locationPermissionStatus = _formatLocationPermission(locationPermission);
      _notificationPermissionStatus =
          notificationPermission.isGranted ? 'Allowed' : 'Not allowed';
    });
  }

  String _formatLocationPermission(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
        return 'Always allowed';
      case LocationPermission.whileInUse:
        return 'Allowed while using app';
      case LocationPermission.denied:
        return 'Denied';
      case LocationPermission.deniedForever:
        return 'Denied permanently';
      case LocationPermission.unableToDetermine:
        return 'Not determined';
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);

    if (!mounted) return;
    setState(() {
      _notificationsEnabled = value;
    });
  }

  Future<void> _toggleDarkMap(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_map_enabled', value);

    if (!mounted) return;
    setState(() {
      _darkMapEnabled = value;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Map theme preference saved.'),
      ),
    );
  }

  Future<void> _openAppSettings() async {
    await openAppSettings();
    await _loadPermissionStatuses();
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Colors.grey.shade200,
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1A6FD4)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String status,
  }) {
    return InkWell(
      onTap: _openAppSettings,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1A6FD4)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A6FD4),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right, color: Colors.black38),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1A6FD4)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
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
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('Notifications'),
          _buildCard(
            children: [
              _buildSwitchRow(
                icon: Icons.notifications_outlined,
                title: 'Enable Notifications',
                subtitle: 'Turn traffic and route alerts on or off',
                value: _notificationsEnabled,
                onChanged: _toggleNotifications,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildSectionTitle('Permissions'),
          _buildCard(
            children: [
              _buildPermissionRow(
                icon: Icons.location_on_outlined,
                title: 'Location Permission',
                subtitle: 'Manage location access for traffic monitoring',
                status: _locationPermissionStatus,
              ),
              _buildDivider(),
              _buildPermissionRow(
                icon: Icons.notifications_active_outlined,
                title: 'Notification Permission',
                subtitle: 'Manage push and local notification access',
                status: _notificationPermissionStatus,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildSectionTitle('Map'),
          _buildCard(
            children: [
              _buildSwitchRow(
                icon: Icons.map_outlined,
                title: 'Dark Map Mode',
                subtitle: 'Use a darker map style when available',
                value: _darkMapEnabled,
                onChanged: _toggleDarkMap,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildSectionTitle('About'),
          _buildCard(
            children: [
              _buildInfoRow(
                icon: Icons.info_outline,
                title: 'HiWay',
                subtitle: 'Traffic alerts, saved routes, and smarter commuting',
              ),
            ],
          ),
        ],
      ),
    );
  }
}