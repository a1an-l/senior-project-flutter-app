import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'edit_profile_page.dart'; 

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String username = '';

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
        });
        return;
      }

      final supabase = Supabase.instance.client;

      final data = await supabase
          .from('users')
          .select('username')
          .eq('user_id', userId)
          .maybeSingle();

      if (data != null) {
        setState(() {
          username = data['username'] ?? '';
        });
      } else {
        setState(() {
          username = '';
        });
      }
    } catch (e) {
      debugPrint('LOADUSERNAME ERROR: $e');
      setState(() {
        username = '';
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
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
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
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfilePage(),
                        ),
                      );

                      if (updated == true && mounted) {
                        await loadUsername();
                      }
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.route_outlined,
                    label: 'My Routes',
                    subtitle: 'View your saved routes',
                    onTap: () {},
                  ),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    subtitle: 'View settings',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),

          // Sign Out
          Container(
            color: const Color(0xFFF2F2F7),
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 32, top: 8),
            child: TextButton(
              onPressed: () {},
              child: const Text(
                'Sign Out',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.red,
                ),
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