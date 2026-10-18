import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/features/auth/application/session_controller.dart';
import 'package:stylist/features/auth/domain/app_user.dart';
import 'package:stylist/features/onboarding/application/onboarding_controller.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/atelier.dart';
import 'package:stylist/theme/tokens.dart';

class BasicsScreen extends ConsumerStatefulWidget {
  const BasicsScreen({super.key});

  @override
  ConsumerState<BasicsScreen> createState() => _BasicsScreenState();
}

class _BasicsScreenState extends ConsumerState<BasicsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _city;
  late Units _units;
  Timer? _debounce;
  List<String> _suggestions = const [];
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(onboardingControllerProvider)!;
    final user = ref.read(sessionControllerProvider).user;
    _name = TextEditingController(
      text: s.displayName ?? user?.displayName ?? '',
    );
    _city = TextEditingController(text: s.city ?? '');
    _units = s.units;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _city.dispose();
    super.dispose();
  }

  void _onCityChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final results = await ref
            .read(placesServiceProvider)
            .autocomplete(text);
        if (mounted && _city.text == text) {
          setState(() {
            _suggestions = results;
            _searched = text.trim().length >= 2;
          });
        }
      } on Object {
        // Autocomplete is a convenience: typing still works without it.
        if (mounted) setState(() => _suggestions = const []);
      }
    });
  }

  void _pick(String city) {
    _debounce?.cancel();
    setState(() {
      _city.text = city;
      _suggestions = const [];
      _searched = false;
    });
  }

  void _submit() => ref
      .read(onboardingControllerProvider.notifier)
      .saveBasics(displayName: _name.text, units: _units, city: _city.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [TextButton(onPressed: _submit, child: Text(l10n.skip))],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(Spacing.lg),
              children: [
                Eyebrow(l10n.basicsEyebrow),
                const SizedBox(height: Spacing.xs),
                Semantics(
                  header: true,
                  child: Text(l10n.basicsTitle, style: textTheme.headlineLarge),
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  l10n.basicsBody,
                  style: textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  maxLength: 100,
                  buildCounter:
                      (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                  autofillHints: const [AutofillHints.givenName],
                  decoration: InputDecoration(labelText: l10n.basicsNameLabel),
                ),
                const SizedBox(height: Spacing.md),
                Text(l10n.basicsUnitsLabel, style: textTheme.labelLarge),
                const SizedBox(height: Spacing.sm),
                SegmentedButton<Units>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: Units.imperial,
                      label: Text(l10n.unitsImperial),
                    ),
                    ButtonSegment(
                      value: Units.metric,
                      label: Text(l10n.unitsMetric),
                    ),
                  ],
                  selected: {_units},
                  onSelectionChanged: (v) => setState(() => _units = v.first),
                ),
                const SizedBox(height: Spacing.lg),
                TextField(
                  controller: _city,
                  textCapitalization: TextCapitalization.words,
                  onChanged: _onCityChanged,
                  decoration: InputDecoration(
                    labelText: l10n.basicsCityLabel,
                    hintText: l10n.basicsCityHint,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                NoteCard(
                  icon: Icons.lock_outline,
                  child: Text(l10n.basicsCityPrivacy),
                ),
                for (final s in _suggestions)
                  ListTile(
                    minTileHeight: Spacing.minTouchTarget,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(s),
                    onTap: () => _pick(s),
                  ),
                if (_searched && _suggestions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: Spacing.sm),
                    child: Text(
                      l10n.cityNoMatches,
                      style: textTheme.bodyMedium,
                    ),
                  ),
                const SizedBox(height: Spacing.xl),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(l10n.continueLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
