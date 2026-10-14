import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stylist/core/analytics/analytics_event.dart';
import 'package:stylist/core/network/api_exception.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/features/closet/application/closet_providers.dart';
import 'package:stylist/features/closet/domain/garment.dart';
import 'package:stylist/features/closet/domain/taxonomy.dart';
import 'package:stylist/features/closet/presentation/closet_routes.dart';
import 'package:stylist/features/closet/presentation/closet_widgets.dart';
import 'package:stylist/features/closet/presentation/garment_fields_editor.dart';
import 'package:stylist/features/onboarding/application/onboarding_controller.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/state_views.dart';
import 'package:stylist/theme/tokens.dart';

/// One garment: edit every field, mark favourite, set it unavailable (laundry, lent, repair), archive,
/// or delete it for good (photos included).
class ItemDetailScreen extends ConsumerStatefulWidget {
  const ItemDetailScreen({required this.garmentId, super.key});
  final String garmentId;

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  final Map<String, Object?> _pending = {};
  final Set<String> _reported = {};
  final _brand = TextEditingController();
  final _notes = TextEditingController();
  bool _textLoaded = false;
  String? _error;

  @override
  void dispose() {
    _brand.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _patch(Map<String, Object?> changes, {Garment? garment}) async {
    setState(() {
      _pending.addAll(changes);
      _error = null;
    });
    if (garment != null) {
      for (final e in changes.entries) {
        final ai = garment.aiFields?[e.key];
        if (ai != null && ai.value != e.value && _reported.add(e.key)) {
          ref.read(analyticsServiceProvider).track(
            AnalyticsEvent.closetItemCorrected,
            {'field': e.key},
          );
        }
      }
    }
    try {
      await ref
          .read(garmentRepositoryProvider)
          .patch(widget.garmentId, changes);
      ref.invalidate(garmentDetailProvider(widget.garmentId));
      ref.invalidate(closetSummaryProvider);
      unawaited(ref.read(closetListProvider.notifier).refresh());
      // wait for the fresh copy so the overlay can drop without flicker
      await ref.read(garmentDetailProvider(widget.garmentId).future);
      if (mounted) setState(() => changes.keys.forEach(_pending.remove));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        changes.keys.forEach(_pending.remove);
        _error = e.code == 'item_limit_reached'
            ? AppLocalizations.of(context).limitReachedSnack(
                ref
                        .read(remoteConfigProvider)
                        .valueOrNull
                        ?.closetItemLimitFree ??
                    30,
              )
            : AppLocalizations.of(context).detailSaveFailed;
      });
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.detailDeleteTitle),
        content: Text(l10n.detailDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.detailDeleteConfirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(garmentRepositoryProvider).delete(widget.garmentId);
    } on ApiException {
      if (mounted) setState(() => _error = l10n.detailSaveFailed);
      return;
    }
    ref.read(analyticsServiceProvider).track(AnalyticsEvent.closetItemDeleted);
    ref.invalidate(closetSummaryProvider);
    ref.invalidate(closetItemsProvider);
    unawaited(ref.read(closetListProvider.notifier).refresh());
    if (mounted) {
      context.canPop() ? context.pop() : context.go(ClosetRoutes.root);
    }
  }

  Future<void> _pickReturnDate(Garment g) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: g.unavailableUntil ?? now.add(const Duration(days: 3)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      await _patch({'unavailable_until': _date(picked)}, garment: g);
    }
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _syncText(Garment g) {
    if (_textLoaded) return;
    _textLoaded = true;
    _brand.text = g.brand ?? '';
    _notes.text = g.notes ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(garmentDetailProvider(widget.garmentId));
    final g = async.valueOrNull;
    if (g != null) _syncText(g);
    final dept = ref.watch(
      onboardingControllerProvider.select((s) => s?.quiz.department),
    );

    bool favorite() => (_pending['favorite'] as bool?) ?? g?.favorite ?? false;
    bool archived() => (_pending['archived'] as bool?) ?? g?.archived ?? false;
    final availability = _pending['availability'] != null
        ? Availability.parse(_pending['availability']! as String)
        : g?.availability ?? Availability.available;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          g == null
              ? l10n.detailTitle
              : garmentName(
                  l10n,
                  category: g.category,
                  subcategory: g.subcategory,
                  color: g.primaryColor,
                ),
        ),
        actions: [
          if (g != null)
            IconButton(
              tooltip: favorite()
                  ? l10n.detailUnfavourite
                  : l10n.detailFavourite,
              isSelected: favorite(),
              icon: const Icon(Icons.favorite_border),
              selectedIcon: const Icon(Icons.favorite),
              onPressed: () => _patch({'favorite': !favorite()}, garment: g),
            ),
          if (g != null)
            PopupMenuButton<String>(
              tooltip: l10n.detailMore,
              onSelected: (v) {
                if (v == 'delete') unawaited(_delete());
                if (v == 'reanalyse') {
                  unawaited(
                    ref
                        .read(garmentRepositoryProvider)
                        .reanalyse(g.id)
                        .then(
                          (_) => ref.invalidate(garmentDetailProvider(g.id)),
                        ),
                  );
                }
              },
              itemBuilder: (_) => [
                if (!g.isSample)
                  PopupMenuItem(
                    value: 'reanalyse',
                    child: Text(l10n.detailReanalyse),
                  ),
                PopupMenuItem(value: 'delete', child: Text(l10n.detailDelete)),
              ],
            ),
        ],
      ),
      body: PageBody(
        child: g == null
            ? async.hasError
                  ? ErrorView(
                      message: l10n.detailLoadFailed,
                      onRetry: () => ref.invalidate(
                        garmentDetailProvider(widget.garmentId),
                      ),
                    )
                  : const LoadingView()
            : ListView(
                children: [
                  _Photo(garment: g),
                  const SizedBox(height: Spacing.md),
                  if (_error != null)
                    Semantics(
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: Spacing.sm),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  if (g.analysisStatus.isWorking)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.md),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(l10n.reviewAnalysing),
                      ),
                    ),
                  GarmentFieldsEditor(
                    values: {...editableValues(g), ..._pending},
                    lowConfidence: {
                      for (final f in g.lowConfidenceFields)
                        if (!_pending.containsKey(f)) f,
                    },
                    department: dept,
                    onChanged: (c) => _patch(c, garment: g),
                  ),
                  _TextFields(
                    brand: _brand,
                    notes: _notes,
                    onSave: (field, text) => _patch({
                      field: text.trim().isEmpty ? null : text.trim(),
                    }, garment: g),
                  ),
                  FieldSection(
                    title: l10n.filterAvailability,
                    children: [
                      for (final a in Availability.values)
                        OptionChip(
                          label: availabilityLabel(l10n, a),
                          selected: availability == a,
                          onTap: () => _patch({
                            'availability': a.name,
                            if (a == Availability.available)
                              'unavailable_until': null,
                          }, garment: g),
                        ),
                    ],
                  ),
                  if (availability != Availability.available)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.md),
                      child: Wrap(
                        spacing: Spacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (g.unavailableUntil != null)
                            Text(
                              l10n.availabilityBack(
                                MaterialLocalizations.of(
                                  context,
                                ).formatMediumDate(g.unavailableUntil!),
                              ),
                            ),
                          OutlinedButton(
                            onPressed: () => _pickReturnDate(g),
                            child: Text(l10n.availabilitySetReturn),
                          ),
                          if (g.unavailableUntil != null)
                            TextButton(
                              onPressed: () => _patch({
                                'unavailable_until': null,
                              }, garment: g),
                              child: Text(l10n.availabilityClearReturn),
                            ),
                        ],
                      ),
                    ),
                  if (g.excludedFromOutfits || archived())
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.md),
                      child: Text(
                        l10n.availabilityNote,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _patch({'archived': !archived()}, garment: g),
                    icon: Icon(
                      archived()
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                    ),
                    label: Text(
                      archived() ? l10n.detailUnarchive : l10n.detailArchive,
                    ),
                  ),
                  if (!archived())
                    Padding(
                      padding: const EdgeInsets.only(top: Spacing.xs),
                      child: Text(
                        l10n.detailArchiveNote,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: Spacing.lg),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.detailDelete),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.garment});
  final Garment garment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cover = garment.cover;
    final name = garmentName(
      l10n,
      category: garment.category,
      subcategory: garment.subcategory,
      color: garment.primaryColor,
    );
    Widget child;
    if (garment.isSample && garment.sampleAsset != null) {
      child = Image.asset(
        'assets/sample_closet/${garment.sampleAsset}.webp',
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      );
    } else if (cover != null && cover.status == ImageStatus.ready) {
      child = GarmentImageView(
        imageId: cover.id,
        url: cover.urlLarge,
        variant: 'l',
        fit: BoxFit.contain,
      );
    } else {
      child = ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      );
    }
    return Semantics(
      image: true,
      label: name,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RadiusTokens.md),
        child: SizedBox(height: 280, width: double.infinity, child: child),
      ),
    );
  }
}

class _TextFields extends StatelessWidget {
  const _TextFields({
    required this.brand,
    required this.notes,
    required this.onSave,
  });
  final TextEditingController brand;
  final TextEditingController notes;
  final void Function(String field, String text) onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Column(
        children: [
          Focus(
            onFocusChange: (has) {
              if (!has) onSave('brand', brand.text);
            },
            child: TextField(
              controller: brand,
              maxLength: Taxonomy.instance.brandMax,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.fieldBrand),
              onSubmitted: (v) => onSave('brand', v),
            ),
          ),
          Focus(
            onFocusChange: (has) {
              if (!has) onSave('notes', notes.text);
            },
            child: TextField(
              controller: notes,
              maxLength: Taxonomy.instance.notesMax,
              maxLines: 3,
              decoration: InputDecoration(labelText: l10n.fieldNotes),
            ),
          ),
        ],
      ),
    );
  }
}
