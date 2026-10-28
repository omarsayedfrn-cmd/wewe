/// Wallet model matching the `wallets` DB table.
class Wallet {
  final String userId;
  final int balance;

  const Wallet({required this.userId, required this.balance});

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        userId: json['user_id'] as String,
        balance: json['balance'] as int? ?? 0,
      );
}

/// A single wallet transaction matching `wallet_transactions`.
class WalletTransaction {
  final String id;
  final String userId;
  final int delta;
  final String reason;
  final String? refId;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.userId,
    required this.delta,
    required this.reason,
    this.refId,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        delta: json['delta'] as int,
        reason: json['reason'] as String,
        refId: json['ref_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  bool get isCredit => delta > 0;
  bool get isDebit => delta < 0;

  String get reasonLabel {
    switch (reason) {
      case 'purchase':
        return 'شراء';
      case 'recharge':
        return 'شحن';
      case 'referral_signup':
        return 'مكافأة إحالة (تسجيل)';
      case 'referral_recharge':
        return 'مكافأة إحالة (شحن)';
      case 'admin_grant':
        return 'منحة من الإدارة';
      default:
        return reason;
    }
  }
}
