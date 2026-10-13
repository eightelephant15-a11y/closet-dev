import 'package:stylist/core/network/api_exception.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';

String errorMessage(AppLocalizations l10n, Object error) =>
    error is ApiException && error.isOffline
    ? l10n.errorOffline
    : l10n.errorGeneric;
