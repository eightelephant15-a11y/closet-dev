import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/core/app_config.dart';

/// Overridden in each flavor entrypoint.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider must be overridden'),
);
