import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';

/// Bug reports go straight to every admin in real time — mirroring how a
/// proposed skill notifies admins (see `proposeSkill` on the backend).
class SupportRepository {
  SupportRepository(this._api);
  final ApiClient _api;

  Future<void> submitBugReport(String description) =>
      _api.postJson('/bug-reports', body: {'description': description});
}

final supportRepositoryProvider = Provider<SupportRepository>(
  (ref) => SupportRepository(ref.watch(apiClientProvider)),
);
