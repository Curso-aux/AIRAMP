import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/routing/app_router.dart';
import 'src/core/theme/app_theme.dart';
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
    // Restore session from SQLite on app start
    Future.microtask(() => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await ref.read(authProvider.notifier).bootstrap();
    if (mounted) {
      setState(() => _bootstrapped = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wait for bootstrap to complete before rendering
    if (!_bootstrapped) {
      return MaterialApp(
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'AIRAMP',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
