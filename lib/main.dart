import 'dart:async';
import 'package:flutter/material.dart';
import 'screens/landing_page.dart';
import 'screens/reset_password.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/background_traffic_service.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/background_tasks.dart';
import 'services/notification_service.dart';
import 'screens/home_map_page.dart';


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
      home: const _StartupGate(),
    );
  }
}

class _StartupGate extends StatelessWidget {
  const _StartupGate();

  Future<Widget> _resolveStart() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;

    final session = Supabase.instance.client.auth.currentSession;
    if (!rememberMe) {
      if (session != null) {
        await Supabase.instance.client.auth.signOut();
      }
      await prefs.remove('user_id');
      return const LandingPage();
    }

    if (session == null) {
      await prefs.remove('user_id');
      return const LandingPage();
    }

    final existingUserId = prefs.getInt('user_id');
    if (existingUserId == null) {
      final email = session.user.email;
      if (email != null && email.isNotEmpty) {
        final row = await Supabase.instance.client
            .from('users')
            .select('user_id')
            .eq('email', email)
            .maybeSingle();
        final userId = row?['user_id'];
        if (userId is int) {
          await prefs.setInt('user_id', userId);
        }
      }
    }

    return const HomeMapPage();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _resolveStart(),
      builder: (context, snapshot) {
        final widget = snapshot.data;
        if (widget != null) {
          return widget;
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
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
