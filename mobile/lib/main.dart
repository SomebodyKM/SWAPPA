import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme_provider.dart';
import 'design_system/app_theme.dart';
import 'features/auth/login_screen.dart';

void main() {
  runApp(const ProviderScope(child: SwappaApp()));
}

class SwappaApp extends ConsumerWidget {
  const SwappaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'SWAPPA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      home: const LoginScreen(),
    );
  }
}
