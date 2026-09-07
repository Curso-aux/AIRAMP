import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/routing/app_router.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/theme/theme_provider.dart';
import 'src/features/auth/application/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: AirampApp(),
    ),
  );
}

class AirampApp extends ConsumerStatefulWidget {
  const AirampApp({super.key});

  @override
  ConsumerState<AirampApp> createState() => _AirampAppState();
}

class _AirampAppState extends ConsumerState<AirampApp> {
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    // Restore session and theme preference from SQLite on app start
    Future.microtask(() => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      ref.read(authProvider.notifier).bootstrap(),
      ref.read(themeProvider.notifier).loadSavedTheme(),
    ]);
    if (mounted) {
      setState(() => _bootstrapped = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    AppTheme.setDark(themeState.isDark);

    // Wait for bootstrap to complete before rendering
    if (!_bootstrapped) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeState.isDark ? ThemeMode.dark : ThemeMode.light,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: AppTheme.background,
          body: Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
        ),
      );
    }

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      key: ValueKey(themeState.isDark),
      title: 'AIRAMP',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeState.isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
