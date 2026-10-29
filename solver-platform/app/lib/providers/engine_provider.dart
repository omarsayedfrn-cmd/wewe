import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/engine.dart';
import '../models/entitlement.dart';
import '../models/product.dart';
import '../models/trial_info.dart';
import '../services/answers_service.dart';
import '../services/engine_service.dart';
import 'auth_provider.dart';

/// Engine service provider.
final engineServiceProvider = Provider<EngineService>((ref) {
  return EngineService(ref.watch(supabaseProvider));
});

/// Server-backed answer bank provider.
final answersServiceProvider = Provider<AnswersService>((ref) {
  return AnswersService(ref.watch(supabaseProvider));
});

/// User's accessible engines.
final myEnginesProvider = FutureProvider<List<Engine>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final service = ref.read(engineServiceProvider);
  var engines = await service.getMyEngines();

  // Self-heal accounts that were onboarded but never got their engine_access
  // rows (e.g. onboarding interrupted by the old RLS error).
  if (engines.isEmpty) {
    try {
      final added = await service.syncEngineAccess();
      if (added > 0) engines = await service.getMyEngines();
    } catch (e) {
      debugPrint('[Engines] access sync skipped: $e');
      // Older backend without the RPC — ignore and show the empty state.
    }
  }

  return engines;
});

/// All engines catalog.
final allEnginesProvider = FutureProvider<List<Engine>>((ref) async {
  return ref.read(engineServiceProvider).getAllEngines();
});

/// User's entitlements.
final entitlementsProvider = FutureProvider<List<Entitlement>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.read(engineServiceProvider).getMyEntitlements();
});

/// Pricing data.
final pricingProvider = FutureProvider<List<Pricing>>((ref) async {
  return ref.read(engineServiceProvider).getPricing();
});

/// Global dashboard settings (trial limits, referral rewards, ...).
final settingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};
  try {
    return await ref.read(engineServiceProvider).getSettings();
  } catch (e) {
    debugPrint('[Settings] failed to load: $e');
    return {};
  }
});

/// Resolved free-trial configuration for the current student.
final trialInfoProvider = FutureProvider<TrialInfo?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  try {
    final profile = await ref.watch(profileProvider.future);
    // Merchants buy at normal prices and have no free trial.
    if (profile == null || profile.grade == null || profile.isMerchant) {
      return null;
    }

    final engineCode = trialEngineFor(profile);
    final settingKey = trialSettingKeyFor(profile);
    if (engineCode == null || settingKey == null) return null;

    final settings = await ref.watch(settingsProvider.future);
    final configured = (settings[settingKey] as num?)?.toInt() ?? 0;

    final entitlements = await ref.watch(entitlementsProvider.future);
    final trialEntitlement = entitlements
        .where((e) =>
            e.source == 'trial' &&
            e.engineCode == engineCode &&
            e.matchesAccount(profile.platformLoginNorm))
        .firstOrNull;

    final chapters = trialEntitlement?.chapters.length ?? configured;
    return TrialInfo(
      engineCode: engineCode,
      chapters: chapters,
      claimed: trialEntitlement != null,
      used: profile.trialUsed,
    );
  } catch (e) {
    debugPrint('[Trial] failed to resolve trial info: $e');
    return null;
  }
});

/// Products (coin packages).
final productsProvider = FutureProvider<List<Product>>((ref) async {
  return ref.read(engineServiceProvider).getProducts();
});
