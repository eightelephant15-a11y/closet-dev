import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/features/onboarding/application/onboarding_controller.dart';
import 'package:stylist/features/onboarding/domain/onboarding_state.dart';
import 'package:stylist/features/permissions/permission_primer.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/state_views.dart';
import 'package:stylist/theme/tokens.dart';

abstract final class OptionalRoutes {
  static const partner = '/optional/partner';
  static const notifications = '/optional/notifications';
}

/// Final onboarding step: both extras are skippable and stay available on Home.
class OptionalStepsScreen extends ConsumerWidget {
  const OptionalStepsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(onboardingControllerProvider);
    final time = state?.notificationTime;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.optionalTitle),
        automaticallyImplyLeading: false,
      ),
      body: PageBody(
        child: ListView(
          children: [
            Text(
              l10n.optionalBody,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: Spacing.lg),
            const OptionalTiles(),
            if (time != null) Text(l10n.optionalSetFor(time)),
            const SizedBox(height: Spacing.lg),
            FilledButton(
              onPressed: ref
                  .read(onboardingControllerProvider.notifier)
                  .completeOptional,
              child: Text(l10n.optionalFinish),
            ),
          ],
        ),
      ),
    );
  }
}

/// The two optional extras, reused on Home.
class OptionalTiles extends StatelessWidget {
  const OptionalTiles({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _Tile(
          icon: Icons.group_add_outlined,
          title: l10n.optionalPartnerTitle,
          body: l10n.optionalPartnerBody,
          onTap: () => context.push(OptionalRoutes.partner),
        ),
        const SizedBox(height: Spacing.sm),
        _Tile(
          icon: Icons.schedule,
          title: l10n.optionalNotifTitle,
          body: l10n.optionalNotifBody,
          onTap: () => context.push(OptionalRoutes.notifications),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      minTileHeight: Spacing.minTouchTarget + 16,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(body),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

/// Placeholder: couples are a later phase.
class PartnerPlaceholderScreen extends StatelessWidget {
  const PartnerPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.partnerTitle)),
      body: PageBody(
        child: CenteredScroll(
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.favorite_border,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text(l10n.partnerBody, textAlign: TextAlign.center),
            const SizedBox(height: Spacing.xl),
            FilledButton(
              onPressed: () => context.pop(),
              child: Text(l10n.gotIt),
            ),
          ],
        ),
      ),
    );
  }
}

/// Daily outfit time. Notification permission is primed here, in context, and
/// the time is saved even if the user declines.
class NotificationTimeScreen extends ConsumerStatefulWidget {
  const NotificationTimeScreen({super.key});

  @override
  ConsumerState<NotificationTimeScreen> createState() =>
      _NotificationTimeScreenState();
}

class _NotificationTimeScreenState
    extends ConsumerState<NotificationTimeScreen> {
  late TimeOfDay _time;
  bool _priming = false;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(onboardingControllerProvider)?.notificationTime;
    _time = saved == null
        ? const TimeOfDay(hour: 8, minute: 0)
        : TimeOfDay(
            hour: int.parse(saved.split(':')[0]),
            minute: int.parse(saved.split(':')[1]),
          );
  }

  String get _hhmm =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  Future<void> _pick() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final ctl = ref.read(onboardingControllerProvider.notifier)
      ..setNotificationTime(_hhmm);
    final granted =
        ref
            .read(onboardingControllerProvider)
            ?.permissions[PermissionKind.notifications] ==
        PermissionOutcome.granted;
    if (granted ||
        await ref
            .read(permissionsServiceProvider)
            .isGranted(PermissionKind.notifications)) {
      ctl.recordPermission(
        PermissionKind.notifications,
        PermissionOutcome.granted,
      );
      if (mounted) context.pop();
    } else if (mounted) {
      setState(() => _priming = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_priming) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.notifTitle)),
        body: PageBody(
          child: Center(
            child: PermissionPrimer(
              kind: PermissionKind.notifications,
              onDone: () => context.pop(),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notifTitle)),
      body: PageBody(
        child: ListView(
          children: [
            Text(l10n.notifBody, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: Spacing.lg),
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.schedule),
              label: Text(
                MaterialLocalizations.of(context).formatTimeOfDay(_time),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Semantics(
              label: l10n.notifChooseTime,
              child: const SizedBox.shrink(),
            ),
            const SizedBox(height: Spacing.lg),
            FilledButton(onPressed: _save, child: Text(l10n.notifSave)),
          ],
        ),
      ),
    );
  }
}
