import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:swappa/main.dart';

void main() {
  testWidgets('App boots to the Discovery screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SwappaApp()));
    await tester.pump();
    // The Discovery app bar shows the wordmark.
    expect(find.text('SWAPPA'), findsOneWidget);
  });
}
