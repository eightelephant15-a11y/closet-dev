// Runs the same journeys as test/flows against fakes, on a real device/emulator:
//   flutter test integration_test --flavor dev
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/flows/flows.dart';
import '../test/helpers/harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('guest journey', (tester) => guestJourney(tester, Harness()));
  testWidgets('google journey', (tester) => googleJourney(tester, Harness()));
}
