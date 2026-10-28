import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/wallet.dart';

/// Service for wallet operations (balance is modified via RPCs only).
class WalletService {
  final SupabaseClient _client;

  WalletService(this._client);

  String get _userId => _client.auth.currentUser!.id;

  /// Get current wallet balance.
  Future<Wallet> getWallet() async {
    final data = await _client
        .from('wallets')
        .select()
        .eq('user_id', _userId)
        .single();
    return Wallet.fromJson(data);
  }

  /// Get transaction history.
  Future<List<WalletTransaction>> getTransactions({int limit = 50}) async {
    final data = await _client
        .from('wallet_transactions')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return data.map((e) => WalletTransaction.fromJson(e)).toList();
  }
}
