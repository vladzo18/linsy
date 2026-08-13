import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ptgyzoaiabrmwjjwdxbu.supabase.co',
    publishableKey: 'sb_publishable_LkYIfHG7IB9vxbgZOS4XAQ_fg6-0-ud',
  );

  runApp(
    const ProviderScope(
      child: LinsyApp(),
    ),
  );
}