import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Splash screen — checks auth state and redirects.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.t.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App mark
            ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Image.asset(
                'assets/branding/logo.png',
                width: 104,
                height: 104,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Solver',
              style: TextStyle(
                color: context.t.onSurface,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'حل واجبات QUREO و SPRIX',
              style: TextStyle(
                color: context.t.onSurfaceVariant,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(strokeWidth: 3),
          ],
        ),
      ),
    );
  }
}