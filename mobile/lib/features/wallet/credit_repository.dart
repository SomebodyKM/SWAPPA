import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';

class CreditBalance {
  const CreditBalance({
    required this.basicBalance,
    required this.basicCap,
    required this.nextRefillAt,
    required this.boostBalance,
  });

  final int basicBalance;
  final int basicCap;
  final DateTime? nextRefillAt;
  final int boostBalance;

  factory CreditBalance.fromJson(Map<String, dynamic> json) {
    final basic = (json['basic'] as Map?)?.cast<String, dynamic>() ?? const {};
    final boost = (json['boost'] as Map?)?.cast<String, dynamic>() ?? const {};
    return CreditBalance(
      basicBalance: (basic['balance'] ?? 0) as int,
      basicCap: (basic['cap'] ?? 0) as int,
      nextRefillAt: DateTime.tryParse((basic['nextRefillAt'] ?? '').toString()),
      boostBalance: (boost['balance'] ?? 0) as int,
    );
  }
}

/// A row in the credit ledger (`GET /credits/transactions`) — always shows
/// exactly one of `basicDelta`/`boostDelta` non-zero in practice (spends draw
/// Basic first, then Boost, but never split a single ledger row across both).
class CreditTxEntry {
  const CreditTxEntry({
    required this.id,
    required this.type,
    this.action,
    required this.basicDelta,
    required this.boostDelta,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String type; // grant | refill | spend | purchase | refund
  final String? action; // icebreaker | insight | rematch | profile_opt
  final int basicDelta;
  final int boostDelta;
  final String? note;
  final DateTime createdAt;

  bool get isBasic => basicDelta != 0 || boostDelta == 0;
  int get amount => basicDelta != 0 ? basicDelta : boostDelta;

  factory CreditTxEntry.fromJson(Map<String, dynamic> json) {
    return CreditTxEntry(
      id: (json['_id'] ?? json['id']).toString(),
      type: (json['type'] ?? '').toString(),
      action: json['action'] as String?,
      basicDelta: (json['basicDelta'] ?? 0) as int,
      boostDelta: (json['boostDelta'] ?? 0) as int,
      note: json['note'] as String?,
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

/// A purchasable Boost pack (`GET /credits/packs`) — display-only catalog;
/// real purchases go through RevenueCat (not yet wired on mobile).
class BoostPack {
  const BoostPack({required this.productId, required this.credits});
  final String productId;
  final int credits;

  factory BoostPack.fromJson(Map<String, dynamic> json) => BoostPack(
    productId: (json['productId'] ?? '').toString(),
    credits: (json['credits'] ?? 0) as int,
  );
}

class CreditRepository {
  CreditRepository(this._api);
  final ApiClient _api;

  Future<CreditBalance> balance() async {
    final data = await _api.getJson('/credits') as Map<String, dynamic>;
    return CreditBalance.fromJson(data);
  }

  Future<List<CreditTxEntry>> transactions({String? cursor}) async {
    final data = await _api.getJson(
      '/credits/transactions',
      query: cursor != null ? {'cursor': cursor} : null,
    );
    final items = (data is Map ? data['items'] : null) as List? ?? const [];
    return items
        .map((e) => CreditTxEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<BoostPack>> packs() async {
    final data = await _api.getJson('/credits/packs');
    final items = (data is Map ? data['items'] : null) as List? ?? const [];
    return items
        .map((e) => BoostPack.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final creditRepositoryProvider = Provider<CreditRepository>(
  (ref) => CreditRepository(ref.watch(apiClientProvider)),
);

final creditBalanceProvider = FutureProvider<CreditBalance>((ref) {
  return ref.watch(creditRepositoryProvider).balance();
});

final creditTransactionsProvider = FutureProvider<List<CreditTxEntry>>((ref) {
  return ref.watch(creditRepositoryProvider).transactions();
});

final boostPacksProvider = FutureProvider<List<BoostPack>>((ref) {
  return ref.watch(creditRepositoryProvider).packs();
});
