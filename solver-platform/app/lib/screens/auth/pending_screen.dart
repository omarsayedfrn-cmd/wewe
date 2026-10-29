import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/secure_credentials.dart';

/// Shown to students whose account is still waiting for admin approval.
class PendingScreen extends ConsumerStatefulWidget {
  const PendingScreen({super.key});

  @override
  ConsumerState<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends ConsumerState<PendingScreen> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // Re-check the approval status automatically so the student is let in as
    // soon as an admin approves the account.
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      ref.invalidate(profileProvider);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _logout() async {
    final userId = ref.read(supabaseProvider).auth.currentUser?.id;
    if (userId != null) {
      await SecureCredentials.clear(userId);
    }
    await ref.read(authServiceProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.t.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: context.t.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hourglass_top_rounded,
                  size: 46,
                  color: context.t.gold,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'حسابك قيد المراجعة',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: context.t.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'تم إنشاء حسابك بنجاح، وهو الآن بانتظار موافقة الإدارة. '
                'سيتم تفعيله قريبًا ويمكنك بعدها البدء في الاستخدام.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: context.t.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ref.invalidate(profileProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('جارٍ التحقق من حالة الحساب')),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('تحديث الحالة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.t.burgundy,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('تسجيل الخروج'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.t.error,
                    side: BorderSide(
                      color: context.t.error.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
