import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/app_state.dart';
import 'screens/auth_gate.dart';

const String supabaseUrl = 'https://dxbrhsefgxcaxzmrbfrb.supabase.co';
const String supabasePublishableKey =
    'sb_publishable_QBdH-vIQv4F_tVVNc4Ps_w_ssxwSaEm';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  await AppState.load();

  runApp(const SkbsApp());
}

class SkbsApp extends StatelessWidget {
  const SkbsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'СКБС',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF7A1A)),
      ),
      home: const AuthGate(),
    );
  }
}
