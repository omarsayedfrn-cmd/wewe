import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/engine.dart';
import '../models/entitlement.dart';
import '../models/product.dart';

/// Service for engine access, entitlements, and pricing.
class EngineService {
  final SupabaseClient _client;

  EngineService(this._client);

  String get _userId => _client.auth.currentUser!.id;

  /// Get all engines from catalog.
  Future<List<Engine>> getAllEngines() async {
    final data = await _client.from('engines').select().order('code');
    return data.map((e) => Engine.fromJson(e)).toList();
  }

  /// Get engines accessible to the current user.
  Future<List<Engine>> getMyEngines() async {
    final data = await _client
        .from('engine_access')
        .select('engine_code, engines(*)')
        .eq('user_id', _userId);
    return data
        .map((row) => Engine.fromJson(row['engines'] as Map<String, dynamic>))
        .toList();
  }

  /// Re-derive the current user's engine_access from their profile.
  /// Repairs accounts whose onboarding was interrupted before the access rows
  /// were written. Returns the number of rows added.
  Future<int> syncEngineAccess() async {
    final result = await _client.rpc('sync_my_engine_access');
    return (result as num?)?.toInt() ?? 0;
  }

  /// Get user's entitlements.
  Future<List<Entitlement>> getMyEntitlements() async {
    final data = await _client
        .from('entitlements')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);
    return data.map((e) => Entitlement.fromJson(e)).toList();
  }

  /// Get pricing for all engines.
  Future<List<Pricing>> getPricing() async {
    final data = await _client.from('pricing').select();
    return data.map((e) => Pricing.fromJson(e)).toList();
  }

  /// Get available products (coin packages).
  Future<List<Product>> getProducts() async {
    final data = await _client
        .from('products')
        .select()
        .eq('active', true)
        .order('sort');
    return data.map((e) => Product.fromJson(e)).toList();
  }

  /// Global settings (trial limits, referral rewards, ...).
  Future<Map<String, dynamic>> getSettings() async {
    final data = await _client.from('settings').select('key, value');
    final map = <String, dynamic>{};
    for (final row in data) {
      final key = row['key'] as String;
      final raw = row['value'];
      if (raw is num) {
        map[key] = raw.toInt();
      } else if (raw is String) {
        map[key] = int.tryParse(raw) ?? raw;
      } else {
        map[key] = raw;
      }
    }
    return map;
  }

  /// Grant the profile's one-time trial entitlement (server-side, idempotent).
  ///
  /// Throws when the RPC fails so the UI can explain why. Callers may still
  /// fall back to the locally configured trial when the backend has not been
  /// migrated yet (see `isMissingBackendFeature`).
  Future<Entitlement?> claimTrial() async {
    final result = await _client.rpc('claim_trial');
    if (result is Map<String, dynamic>) {
      return Entitlement.fromJson(result);
    }
    if (result is Map) {
      return Entitlement.fromJson(Map<String, dynamic>.from(result));
    }
    if (result is List && result.isNotEmpty) {
      final first = result.first;
      if (first is Map) {
        return Entitlement.fromJson(Map<String, dynamic>.from(first));
      }
    }
    return null;
  }

  /// Purchase an engine (full or chapters) using RPC.
  Future<String> purchaseEngine({
    required String engineCode,
    required String scope,
    List<int> chapters = const [],
  }) async {
    final result = await _client.rpc('purchase_engine', params: {
      'p_engine_code': engineCode,
      'p_scope': scope,
      'p_chapters': chapters,
    });
    return result as String;
  }

  /// Check if user has entitlement for a specific engine/chapter.
  bool hasEntitlement(
      List<Entitlement> entitlements, String engineCode, int? chapter) {
    for (final e in entitlements) {
      if (e.engineCode != engineCode) continue;
      if (e.isFull) return true;
      if (chapter != null && e.hasChapter(chapter)) return true;
    }
    return false;
  }
}
