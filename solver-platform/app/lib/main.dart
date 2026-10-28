import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'core/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep uncaught errors visible in the console for diagnostics while showing
  // a friendly screen to the student instead of the raw red error widget.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint(
      '[FlutterError] ${details.exceptionAsString()}\n${details.stack}',
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[Uncaught] $error\n$stack');
    return true;
  };
  ErrorWidget.builder = (details) => _FatalErrorScreen(details: details);

  // Initialize Supabase
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    publishableKey: AppConstants.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: SolverApp()));
}

/// Last-resort screen for build errors that nothing else caught.
class _FatalErrorScreen extends StatelessWidget {
  final FlutterErrorDetails details;

  const _FatalErrorScreen({required this.details});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: SolverTheme.background,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: SolverTheme.error,
                  size: 52,
                ),
                const SizedBox(height: 16),
                const Text(
                  'حدث خطأ غير متوقع',
                  style: TextStyle(
                    color: SolverTheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'يرجى إعادة تشغيل التطبيق. إذا استمرت المشكلة تواصل مع الدعم الفني.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: SolverTheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 20),
                  SelectableText(
                    details.exceptionAsString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: SolverTheme.onSurfaceVariant,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SolverApp extends ConsumerWidget {
  const SolverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Solver',
      debugShowCheckedModeBanner: false,
      theme: SolverTheme.darkTheme,
      routerConfig: router,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
    );
  }
}
