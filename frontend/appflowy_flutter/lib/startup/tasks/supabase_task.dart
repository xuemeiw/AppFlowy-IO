import 'package:appflowy/core/config/config.dart';
import 'package:appflowy_backend/log.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../startup.dart';

bool isSupabaseEnable = false;

class InitSupabaseTask extends LaunchTask {
  const InitSupabaseTask({
    required this.url,
    required this.anonKey,
    required this.jwtSecret,
  });

  final String url;
  final String anonKey;
  final String jwtSecret;

  @override
  Future<void> initialize(LaunchContext context) async {
    if (url.isEmpty || anonKey.isEmpty || jwtSecret.isEmpty) {
      isSupabaseEnable = false;
      Log.info('Supabase config is empty, skip init supabase.');
      return;
    }
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
    await Config.setSupabaseConfig(
      url: url,
      key: anonKey,
      secret: jwtSecret,
    );
    isSupabaseEnable = false;
  }
}
