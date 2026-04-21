import 'package:flutter/material.dart';
import '../services/background_traffic_service.dart';
import '../config/api_config.dart';

class TrafficSettingsPage extends StatefulWidget {
  const TrafficSettingsPage({super.key});

  @override
  State<TrafficSettingsPage> createState() => _TrafficSettingsPageState();
}

class _TrafficSettingsPageState extends State<TrafficSettingsPage> {
  bool _isEnabled = false;
  int _intervalMinutes = 15;
  double _radiusMiles = defaultDetectionRadiusMiles.toDouble();
  bool _notifyOnlySerious = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    print('[TrafficSettings] Loading settings...');
    final settings = await BackgroundTrafficService.getTrafficSettings();
    print(
      '[TrafficSettings] Loaded settings: enabled=${settings['enabled']}, interval=${settings['intervalMinutes']}min, radius=${settings['radiusMiles']}mi',
    );
    setState(() {
      _isEnabled = settings['enabled'];
      _intervalMinutes = settings['intervalMinutes'];
      _radiusMiles = settings['radiusMiles'];
      _notifyOnlySerious = settings['notifyOnlySerious'];
      _isLoading = false;
    });
    print('[TrafficSettings] Settings loaded and UI updated');
  }

  Future<void> _saveSettings() async {
    print('[TrafficSettings] Saving settings... enabled: $_isEnabled');
    setState(() => _isLoading = true);

    if (_isEnabled) {
      print('[TrafficSettings] Starting traffic monitoring...');
      await BackgroundTrafficService.startTrafficMonitoring(
        intervalMinutes: _intervalMinutes,
        radiusMiles: _radiusMiles,
        notifyOnlySerious: _notifyOnlySerious,
      );
      print('[TrafficSettings] Traffic monitoring started');
    } else {
      print('[TrafficSettings] Stopping traffic monitoring...');
      await BackgroundTrafficService.stopTrafficMonitoring();
      print('[TrafficSettings] Traffic monitoring stopped');
    }

    setState(() => _isLoading = false);
    print('[TrafficSettings] Settings saved successfully');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEnabled
                ? 'Traffic monitoring started'
                : 'Traffic monitoring stopped',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0066CC), Color(0xFF007AFF)],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const Text(
                        'Traffic Detection Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Traffic Detection',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Monitor traffic conditions around your location and get notified when congestion is detected.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  // Enable/Disable Switch
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Enable Traffic Monitoring',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Receive notifications about traffic conditions',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _isEnabled,
                                onChanged: (value) {
                                  setState(() => _isEnabled = value);
                                  _saveSettings();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Status indicator
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _isEnabled
                                  ? Colors.green.shade50
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _isEnabled
                                    ? Colors.green.shade200
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              _isEnabled
                                  ? 'Monitoring Active'
                                  : 'Monitoring Inactive',
                              style: TextStyle(
                                color: _isEnabled
                                    ? Colors.green.shade700
                                    : Colors.grey.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Detection Radius Slider
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detection Radius: ${_radiusMiles.round()} miles',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Slider(
                            value: _radiusMiles,
                            min: minDetectionRadiusMiles.toDouble(),
                            max: maxDetectionRadiusMiles.toDouble(),
                            divisions:
                                maxDetectionRadiusMiles -
                                minDetectionRadiusMiles,
                            label: '${_radiusMiles.round()} miles',
                            onChanged: _isEnabled
                                ? (value) {
                                    setState(() => _radiusMiles = value);
                                  }
                                : null,
                            onChangeEnd: (value) => _saveSettings(),
                          ),
                          const Text(
                            'Check traffic conditions within this radius from your location',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Check Interval
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Check Interval',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButton<int>(
                            value: _intervalMinutes,
                            isExpanded: true,
                            items: [1, 5, 10, 15, 30, 60].map((minutes) {
                              return DropdownMenuItem(
                                value: minutes,
                                child: Text(
                                  minutes == 1
                                      ? 'Every minute'
                                      : minutes < 60
                                      ? 'Every $minutes minutes'
                                      : 'Every hour',
                                ),
                              );
                            }).toList(),
                            onChanged: _isEnabled
                                ? (value) {
                                    if (value != null) {
                                      setState(() => _intervalMinutes = value);
                                      _saveSettings();
                                    }
                                  }
                                : null,
                          ),
                          const Text(
                            'How often to check for traffic conditions',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Notification Preferences
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Notification Preferences',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Notify only on serious traffic'),
                                    SizedBox(height: 4),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _notifyOnlySerious,
                                onChanged: _isEnabled
                                    ? (value) {
                                        setState(
                                          () => _notifyOnlySerious = value,
                                        );
                                        _saveSettings();
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Test Traffic Check Button
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Test Traffic Detection',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Manually trigger a traffic check to test the system',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                print(
                                  '[TrafficSettings] Manual traffic check triggered',
                                );
                                await BackgroundTrafficService.performTrafficCheck();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Traffic check completed - check console logs',
                                    ),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Test Traffic Check'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                   /*Card(
                    color: Colors.blue.shade50,
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How it works',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'The app checks traffic conditions in four directions (North, South, East, West) around your location. '
                            'Traffic is categorized as:\n\n'
                            '• Free Flow: Minimal delays\n'
                            '• Congested: Moderate delays\n'
                            '• Serious: Heavy congestion\n\n'
                            'Background checks continue even when the app is closed.',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ), */
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
