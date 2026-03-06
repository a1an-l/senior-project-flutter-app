import 'package:flutter/material.dart';
import 'home_map_page.dart';
import 'location_input_page.dart';


class LocationSetupScreen extends StatelessWidget {
  const LocationSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Blue header section
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
            padding: const EdgeInsets.only(
              top: 80,
              bottom: 36,
              left: 24,
              right: 24,
            ),
            child: Column(
              children: const [
                Text(
                  "Let's get to know\nyou!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Add your favorite places to personalize\nyour experience',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // pill cards
          Expanded(
            child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: const [
                  _LocationItem(
                    icon: Icons.home_rounded,
                    iconColor: Color(0xFFE53935),
                    label: 'Home',
                    subtitle: 'Add your home address',
                  ),
                  SizedBox(height: 12),
                  _LocationItem(
                    icon: Icons.work_rounded,
                    iconColor: Color(0xFF1A3ED4),
                    label: 'Work',
                    subtitle: 'Add your work address',
                  ),
                  SizedBox(height: 12),
                  _LocationItem(
                    icon: Icons.edit_rounded,
                    iconColor: Color(0xFFD4860A),
                    label: 'School',
                    subtitle: 'Add your school address',
                  ),
                  SizedBox(height: 12),
                  _LocationItem(
                    icon: Icons.fitness_center_rounded,
                    iconColor: Color(0xFF1FCC00),
                    label: 'Gym',
                    subtitle: 'Add your gym address',
                  ),
                  SizedBox(height: 12),
                  _LocationItem(
                    icon: Icons.location_on_rounded,
                    iconColor: Color(0xFF00BCD4),
                    label: 'Other',
                    subtitle: 'Add any other address',
                  ),
                ],
            ),
          ),

          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A6FD4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeMapPage()),
                      );
                    },
                    child: const Text(
                      'Complete Set Up',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeMapPage()),
                      );
                    },
                    child: const Text(
                      'Set up later',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;

  const _LocationItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(0, 0, 0, 0.07),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
      ),
      child: InkWell(
        onTap: () {
           Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LocationInputPage(
                title: label,
                placeholder: 'Enter $label address',
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
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
                        fontSize: 13,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black38, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
