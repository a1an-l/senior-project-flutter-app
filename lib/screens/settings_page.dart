import '../main.dart';
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
  bool _darkModeEnabled = false;

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
      _darkModeEnabled = prefs.getBool('dark_mode') ?? false;
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPermissionStatuses();
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

  Future<void> _toggleDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);

    if (!mounted) return;

    setState(() {
      _darkModeEnabled = value;
    });

    await MyApp.of(context)?.setDarkMode(value);
  }

  Future<void> _openAppSettings() async {
    await openAppSettings();
    await _loadPermissionStatuses();
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: theme.textTheme.bodySmall?.color,
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required List<Widget> children}) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.18 : 0.04,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final theme = Theme.of(context);

    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: theme.dividerColor,
    );
  }

  Widget _buildSwitchRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color,
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
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required String status,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: _openAppSettings,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodySmall?.color,
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
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.chevron_right,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color,
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle(context, 'Notifications'),
          _buildCard(
            context,
            children: [
              _buildSwitchRow(
                context: context,
                icon: Icons.notifications_outlined,
                title: 'Enable Notifications',
                subtitle: 'Turn traffic and route alerts on or off',
                value: _notificationsEnabled,
                onChanged: _toggleNotifications,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildSectionTitle(context, 'Permissions'),
          _buildCard(
            context,
            children: [
              _buildPermissionRow(
                context: context,
                icon: Icons.location_on_outlined,
                title: 'Location Permission',
                subtitle: 'Manage location access for traffic monitoring',
                status: _locationPermissionStatus,
              ),
              _buildDivider(context),
              _buildPermissionRow(
                context: context,
                icon: Icons.notifications_active_outlined,
                title: 'Notification Permission',
                subtitle: 'Manage push and local notification access',
                status: _notificationPermissionStatus,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildSectionTitle(context, 'Appearance'),
          _buildCard(
            context,
            children: [
              _buildSwitchRow(
                context: context,
                icon: Icons.dark_mode_outlined,
                title: 'Dark Mode',
                subtitle: 'Use dark theme throughout the app',
                value: _darkModeEnabled,
                onChanged: _toggleDarkMode,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildSectionTitle(context, 'About'),
          _buildCard(
            context,
            children: [
              _buildInfoRow(
                context: context,
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