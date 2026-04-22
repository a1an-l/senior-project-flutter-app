import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'traffic_settings_page.dart';
import 'my_addresses.dart';
import 'edit_profile_page.dart'; 

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

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
    //debugPrint('here');

    try {
      final prefs = await SharedPreferences.getInstance();
      final int? userId = prefs.getInt('user_id');

      debugPrint('user id: $userId');
      //if user is signed out dipslay guest
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
    return Scaffold(
      body: Column(
        children: [
          // Blue header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A6FD4),
                  Color(0xFF2196F3),
                ],
              ),
            ),
            padding: const EdgeInsets.only(top: 60, bottom: 32),
            child: Column(
              children: [
                // Close button top right
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                // Avatar
                CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
                    child: photoUrl == null
                        ? const Icon(
                            Icons.person,
                            size: 40,
                            color: Color(0xFF1A6FD4),
                          )
                        : null,
                  ),
                const SizedBox(height: 14),
                Text(
                  username.isEmpty ? 'Hi!' : 'Hi $username!', //defualt to Hi if not signed in
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          // Menu items
          Expanded(
            child: Container(
              color: const Color(0xFFF2F2F7),
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
                          const SnackBar(content: Text('Please sign in to view your profile.')),
                        );
                        return;
                      }

                      final supabase = Supabase.instance.client;

                      // Reuse the same query pattern as loadUsername(), just grab email too
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
                    label: 'My Routes',
                    subtitle: 'View your saved routes',
                    onTap: () {
                      Navigator.pop(context);
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
                    onTap: () {},
                  ),
                  _DrawerItem(
                    icon: Icons.traffic_outlined,
                    label: 'Radius Traffic Detection',
                    subtitle: 'Monitor traffic around you',
                    onTap: () {
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TrafficSettingsPage(),
                        ),
                      );
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Row(
            children: [
              Icon(icon, size: 22, color: Colors.black87),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
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
              const Icon(Icons.chevron_right, color: Colors.black38, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}