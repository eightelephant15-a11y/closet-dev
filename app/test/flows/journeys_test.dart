import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';
import 'flows.dart';

void main() {
  testWidgets('full guest journey with upgrade on save', (tester) async {
    await guestJourney(tester, Harness());
  });

  testWidgets('full Google sign-in journey', (tester) async {
    await googleJourney(tester, Harness());
  });
}
