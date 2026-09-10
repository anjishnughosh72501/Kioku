/// Kioku App Entry Point
/// Initializes services, sets up providers, and runs the app
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_mobile/core/services/user_profile_service.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UserProfileService.instance.init();

  runApp(
    const ProviderScope(
      child: KiokuApp(),
    ),
  );
}

/// Main app widget with theming and routing
class KiokuApp extends ConsumerWidget {
  const KiokuApp({super.key});

@override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Kioku 記憶',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.coffeeLight(),
      darkTheme: AppTheme.forestDark(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 2.5,
            ),
          ),
          child: child!,
        );
      },
    );
  }
}

/// Theme mode provider (persisted)
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('theme_dark') ?? true;
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = state == ThemeMode.dark;
    state = isDark ? ThemeMode.light : ThemeMode.dark;
    await prefs.setBool('theme_dark', !isDark);
  }
}


