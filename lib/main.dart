import 'dart:async';
import 'package:flutter/material.dart';
import 'screens/landing_page.dart';
import 'screens/reset_password.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/background_traffic_service.dart';
import 'package:workmanager/workmanager.dart';

import 'services/background_tasks.dart';
import 'services/notification_service.dart';


final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  await NotificationService.instance.init(onTap: (_) {});
  await NotificationService.instance.requestAndroidPermissionIfNeeded();

  try {
    await Supabase.initialize(
      url: 'https://mzpdwpmbtsnenqqvhjzo.supabase.co/',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im16cGR3cG1idHNuZW5xcXZoanpvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE0MzgzOTcsImV4cCI6MjA4NzAxNDM5N30._RdzvMz7-IjUDnxeRRJ3kbK7RAvVSt2D9TKUy9XHxFw',
    );
    debugPrint('Supabase initialized successfully');
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
  }

  // Initialize background traffic service asynchronously (non-blocking)
  print('[App] Initializing background traffic service...');
  unawaited(BackgroundTrafficService.initialize().then((_) {
    print('[App] Background traffic service initialized successfully');
  }).catchError((e) {
    print('[App] Error initializing background traffic service: $e');
  }));
  
  runApp(const MyApp());
}



class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        final event = data.event;

        if (event == AuthChangeEvent.passwordRecovery) {
          appNavigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => const ResetPasswordPage(),
            ),
          );
        }
      },
      onError: (error) {
        debugPrint('Auth state listener error: $error');
      },
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      home: const LandingPage(),
    );
  }
}
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return const MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: LandingPage(),
//     );
//   }
//}
