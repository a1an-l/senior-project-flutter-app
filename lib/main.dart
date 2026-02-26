import 'package:flutter/material.dart';
import 'screens/landing_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: 'https://mzpdwpmbtsnenqqvhjzo.supabase.co/',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im16cGR3cG1idHNuZW5xcXZoanpvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE0MzgzOTcsImV4cCI6MjA4NzAxNDM5N30._RdzvMz7-IjUDnxeRRJ3kbK7RAvVSt2D9TKUy9XHxFw',
    );
    print('Supabase initialized successfully');
  } catch (e) {
    print('Supabase initialization error: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LandingPage(),
    );
  }
}
