import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'my_addresses.dart';
import 'edit_profile_page.dart';
import 'settings_page.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({
    super.key,
    required this.onOpenTrafficSettings,
    required this.onSettingsClosed,
  });

  final VoidCallback onOpenTrafficSettings;
  final Future<void> Function() onSettingsClosed;

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String username = '';
  String? photoUrl;

  @override
  void initState() {
    super.initState();
    loadUsername();
  }

  Future<void> loadUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? userId = prefs.getInt('user_id');

      debugPrint('user id: $userId');

      if (userId == null) {
        setState(() {
          username = 'Guest!';
          photoUrl = null;
        });
        return;
      }

      final supabase = Supabase.instance.client;

      final data = await supabase
          .from('users')
          .select('username, photo')
          .eq('user_id', userId)
          .maybeSingle();

      if (data != null) {
        final photo = data['photo'];

        setState(() {
          username = data['username'] ?? '';
          photoUrl = photo is Map ? photo['url'] as String? : null;
        });
      } else {
        setState(() {
          username = '';
          photoUrl = null;
        });
      }
    } catch (e) {
      debugPrint('LOADUSERNAME ERROR: $e');
      setState(() {
        username = '';
        photoUrl = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark ? theme.cardColor: const Color(0xFF1A6FD4),
              border: Border(
                bottom: BorderSide(
                  color: theme.brightness == Brightness.dark
                      ? theme.dividerColor.withOpacity(0.4)
                      : Colors.transparent,
                ),
              ),
            ),
            padding: const EdgeInsets.only(top: 60, bottom: 32),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: IconButton(
                      icon: Icon(
                        Icons.chevron_right,
                        color: theme.brightness == Brightness.dark ? theme.colorScheme.onSurface : Colors.white,
                        size: 28,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2A2A2A)
                      : Colors.white,
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
                  child: photoUrl == null
                      ? Icon(
                          Icons.person,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                ),
                const SizedBox(height: 14),
                Text(
                  username.isEmpty ? 'Hi!' : 'Hi $username!',
                  style: TextStyle(
                    color: theme.brightness == Brightness.dark ? theme.colorScheme.onSurface : Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Container(
              color: theme.scaffoldBackgroundColor,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _DrawerItem(
                    icon: Icons.person_outline,
                    label: 'Profile',
                    subtitle: 'View and Edit your profile',
                    onTap: () async {
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        final int? userId = prefs.getInt('user_id');

                        if (userId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Please sign in to view your profile.'),
                            ),
                          );
                          return;
                        }

                        final supabase = Supabase.instance.client;

                        final data = await supabase
                            .from('users')
                            .select('username, email')
                            .eq('user_id', userId)
                            .maybeSingle();

                        if (data == null || !mounted) return;

                        final updated = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditProfilePage(
                              userId: userId,
                              currentUsername: data['username'] ?? '',
                              currentEmail: data['email'] ?? '',
                            ),
                          ),
                        );

                        if (updated == true && mounted) {
                          await loadUsername();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to load profile: $e')),
                          );
                        }
                      }
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.route_outlined,
                    label: 'My Addresses',
                    subtitle: 'View your saved addresses',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyAddresses(),
                        ),
                      );
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    subtitle: 'View settings',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsPage(),
                        ),
                      );

                      await widget.onSettingsClosed();
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.traffic_outlined,
                    label: 'Radius Traffic Detection',
                    subtitle: 'Monitor traffic around you',
                    onTap: () {
                      widget.onOpenTrafficSettings();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.18 : 0.05,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.4),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
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
              Icon(
                Icons.chevron_right,
                color: theme.textTheme.bodySmall?.color,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}