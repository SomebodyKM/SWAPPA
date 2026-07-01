import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'token_store.dart';

/// Secure token storage (single instance).
final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

/// Configured Dio API client with auth + refresh.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(tokenStoreProvider));
});
