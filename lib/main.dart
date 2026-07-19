import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/db/database.dart';
import 'core/providers/app_providers.dart';
import 'core/seed/content_seeder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  // Local-first: open the DB and seed bundled content on first launch
  final db = AppDatabase();
  await ContentSeeder(db).seedIfNeeded();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const HattApp(),
    ),
  );
}
