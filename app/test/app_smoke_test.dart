import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/app.dart';
import 'package:stylist/core/app_config.dart';
import 'package:stylist/core/providers.dart';

void main() {
  testWidgets('app boots to home in mock config', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(AppConfig.forFlavor(Flavor.dev)),
        ],
        child: const StylistApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your stylist is getting ready.'), findsOneWidget);
  });
}
