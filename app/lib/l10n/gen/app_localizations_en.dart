// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Stylist';

  @override
  String get homeTitle => 'Home';

  @override
  String get homePlaceholder => 'Your stylist is getting ready.';

  @override
  String get loading => 'Loading';

  @override
  String get errorGeneric => 'Something went wrong.';

  @override
  String get retry => 'Try again';

  @override
  String get offlineBanner =>
      'You\'re offline. Changes will sync when you reconnect.';

  @override
  String get emptyState => 'Nothing here yet.';
}
