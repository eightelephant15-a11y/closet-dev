import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:stylist/features/onboarding/domain/onboarding_state.dart';

abstract class PermissionsService {
  Future<bool> isGranted(PermissionKind kind);

  /// Shows the OS prompt (call only after our own priming screen).
  Future<PermissionOutcome> request(PermissionKind kind);

  Future<void> openSettings();
}

class DevicePermissionsService implements PermissionsService {
  ph.Permission _map(PermissionKind k) => switch (k) {
    PermissionKind.camera => ph.Permission.camera,
    PermissionKind.photos => ph.Permission.photos,
    PermissionKind.location => ph.Permission.locationWhenInUse,
    PermissionKind.notifications => ph.Permission.notification,
  };

  @override
  Future<bool> isGranted(PermissionKind kind) async {
    final s = await _map(kind).status;
    return s.isGranted || s.isLimited || s.isProvisional;
  }

  @override
  Future<PermissionOutcome> request(PermissionKind kind) async {
    final s = await _map(kind).request();
    return s.isGranted || s.isLimited || s.isProvisional
        ? PermissionOutcome.granted
        : PermissionOutcome.denied;
  }

  @override
  Future<void> openSettings() async {
    await ph.openAppSettings();
  }
}

/// Scriptable fake for mock mode and tests.
class FakePermissionsService implements PermissionsService {
  FakePermissionsService({Map<PermissionKind, PermissionOutcome>? outcomes})
    : outcomes = outcomes ?? {};

  /// Defaults to granted.
  final Map<PermissionKind, PermissionOutcome> outcomes;
  final List<PermissionKind> requested = [];
  int settingsOpened = 0;

  @override
  Future<bool> isGranted(PermissionKind kind) async =>
      requested.contains(kind) &&
      (outcomes[kind] ?? PermissionOutcome.granted) ==
          PermissionOutcome.granted;

  @override
  Future<PermissionOutcome> request(PermissionKind kind) async {
    requested.add(kind);
    return outcomes[kind] ?? PermissionOutcome.granted;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}
