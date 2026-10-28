import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wallet.dart';
import '../services/wallet_service.dart';
import 'auth_provider.dart';

/// Wallet service provider.
final walletServiceProvider = Provider<WalletService>((ref) {
  return WalletService(ref.watch(supabaseProvider));
});

/// Wallet balance provider.
final walletProvider = FutureProvider<Wallet>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) throw Exception('Not authenticated');
  return ref.read(walletServiceProvider).getWallet();
});

/// Transaction history provider.
final transactionsProvider =
    FutureProvider<List<WalletTransaction>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.read(walletServiceProvider).getTransactions();
});
