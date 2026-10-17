import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stylist/core/analytics/analytics_event.dart';
import 'package:stylist/core/network/api_exception.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/features/closet/application/closet_providers.dart';
import 'package:stylist/features/closet/application/upload_queue.dart';
import 'package:stylist/features/closet/domain/garment.dart';
import 'package:stylist/features/closet/presentation/closet_routes.dart';
import 'package:stylist/features/closet/presentation/closet_widgets.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/atelier.dart';
import 'package:stylist/shared/widgets/state_views.dart';
import 'package:stylist/theme/tokens.dart';
import 'package:uuid/uuid.dart';

const bulkMax = 20;

/// Add up to 20 photos at once. They go through the same background upload queue as single adds,
/// then show up here as a review queue with an "Accept all" shortcut.
class BulkAddScreen extends ConsumerStatefulWidget {
  const BulkAddScreen({super.key});

  @override
  ConsumerState<BulkAddScreen> createState() => _BulkAddScreenState();
}

class _BulkAddScreenState extends ConsumerState<BulkAddScreen> {
  String? _batch;
  int _preparing = 0;
  int _total = 0;
  bool _tooMany = false;
  bool _completedReported = false;
  bool _accepting = false;
  int? _accepted;
  String? _error;

  Future<void> _pick(int room) async {
    final cap = room.clamp(0, bulkMax);
    final picks = await ref
        .read(imageSourceServiceProvider)
        .pickFromLibrary(limit: bulkMax + 1);
    if (picks.isEmpty || !mounted) return;
    final chosen = picks.take(cap).toList();
    final batch = const Uuid().v4();
    setState(() {
      _batch = batch;
      _total = chosen.length;
      _tooMany = picks.length > cap;
      _preparing = chosen.length;
      _completedReported = false;
      _accepted = null;
      _error = null;
    });
    ref.read(analyticsServiceProvider).track(
      AnalyticsEvent.closetBulkAddStarted,
      {'count': chosen.length},
    );
    final queue = ref.read(uploadQueueProvider);
    final processor = ref.read(imageProcessorProvider);
    for (final p in chosen) {
      try {
        await queue.enqueue(await processor.process(p), batchId: batch);
      } on Object {
        if (mounted) {
          setState(() => _error = AppLocalizations.of(context).captureBad);
        }
      }
      if (mounted) setState(() => _preparing--);
    }
  }

  Future<void> _acceptAll(List<String> ids) async {
    setState(() => _accepting = true);
    final repo = ref.read(garmentRepositoryProvider);
    var n = 0;
    for (final id in ids) {
      try {
        await repo.patch(id, {'reviewed': true});
        n++;
      } on ApiException {
        // leave it in the queue for a manual look
      }
    }
    ref.invalidate(closetSummaryProvider);
    unawaited(ref.read(closetListProvider.notifier).refresh());
    if (mounted) {
      setState(() {
        _accepting = false;
        _accepted = n;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final config = ref.watch(remoteConfigProvider).valueOrNull;
    final summary = ref.watch(closetSummaryProvider).valueOrNull;
    final all =
        ref.watch(uploadItemsProvider).valueOrNull ?? const <UploadItem>[];
    final mine = _batch == null
        ? const <UploadItem>[]
        : all.where((i) => i.batchId == _batch).toList();
    final settled = mine.where((i) => !i.isActive).length;
    final uploaded = mine.where((i) => i.state == UploadState.done).length;
    final finished =
        _batch != null &&
        _preparing == 0 &&
        mine.length == _total &&
        settled == _total;
    if (finished && !_completedReported) {
      _completedReported = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(analyticsServiceProvider).track(
          AnalyticsEvent.closetBulkAddCompleted,
          {
            'count': _total,
            'uploaded': uploaded,
            'failed': _total - uploaded,
          },
        );
      });
    }

    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final stage = _batch == null ? 0 : (finished ? 2 : 1);
    final percent = _total == 0 ? 100 : (settled * 100 ~/ _total);
    final steps = [
      l10n.bulkStepPick,
      l10n.bulkStepUpload,
      l10n.bulkStepReview,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.bulkTitle),
        leading: IconButton(
          tooltip: l10n.close,
          icon: const Icon(Icons.close),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(ClosetRoutes.root),
        ),
      ),
      body: PageBody(
        child: config != null && !config.closetBulkAddEnabled
            ? EmptyView(message: l10n.bulkDisabled)
            : summary == null
            ? const LoadingView()
            : ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.all(Spacing.xs),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(RadiusTokens.lg),
                    ),
                    child: Row(
                      children: [
                        for (var i = 0; i < steps.length; i++)
                          Expanded(
                            child: Semantics(
                              label: steps[i],
                              selected: i == stage,
                              child: Container(
                                alignment: Alignment.center,
                                constraints: const BoxConstraints(
                                  minHeight: Spacing.minTouchTarget - 8,
                                ),
                                padding: const EdgeInsets.all(Spacing.xs),
                                decoration: BoxDecoration(
                                  color: i == stage
                                      ? scheme.surfaceContainerLowest
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(
                                    RadiusTokens.md,
                                  ),
                                ),
                                child: ExcludeSemantics(
                                  child: Text(
                                    steps[i],
                                    textAlign: TextAlign.center,
                                    style: text.labelMedium?.copyWith(
                                      color: i == stage
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  if (_batch == null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(
                            RadiusTokens.pill,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.sm + 4,
                            vertical: Spacing.xs + 2,
                          ),
                          child: Text(
                            l10n.bulkRoom(summary.remaining),
                            style: text.labelMedium,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.sm + 4),
                    Semantics(
                      header: true,
                      child: Text(l10n.bulkHeadline, style: text.headlineLarge),
                    ),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      l10n.bulkBody(bulkMax),
                      style: text.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    Container(
                      padding: const EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(RadiusTokens.xl),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Column(
                        children: [
                          const BadgeIcon(
                            icon: Icons.photo_library_outlined,
                          ),
                          const SizedBox(height: Spacing.md),
                          Text(
                            l10n.bulkPickCardTitle,
                            style: text.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: Spacing.xs),
                          Text(
                            l10n.bulkPickCardBody,
                            textAlign: TextAlign.center,
                            style: text.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: Spacing.md),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: summary.remaining == 0
                                  ? () => context.pushReplacement(
                                      ClosetRoutes.upgrade,
                                    )
                                  : () => _pick(summary.remaining),
                              icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                              ),
                              label: Text(l10n.bulkPick),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    if (_tooMany)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Spacing.sm),
                        child: Text(l10n.bulkTooMany(_total)),
                      ),
                    if (_error != null)
                      Text(_error!, style: TextStyle(color: scheme.error)),
                    Row(
                      children: [
                        Expanded(child: Eyebrow(l10n.uploadSheetTitle)),
                        Text(
                          '$percent%',
                          style: text.labelLarge?.copyWith(
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.xs),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        finished
                            ? l10n.bulkFinished
                            : l10n.bulkProgress(uploaded, _total),
                        style: text.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    LinearProgressIndicator(
                      value: _total == 0 ? 1 : settled / _total,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: Spacing.md),
                    const UploadBanner(),
                    const SizedBox(height: Spacing.md),
                    _ReviewQueue(
                      items: mine.where((i) => i.garmentId != null).toList(),
                      accepting: _accepting,
                      accepted: _accepted,
                      onAccept: _acceptAll,
                    ),
                    if (finished) ...[
                      const SizedBox(height: Spacing.md),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: scheme.surfaceContainerLowest,
                          foregroundColor: scheme.onSurface,
                        ),
                        onPressed: () => context.go(ClosetRoutes.root),
                        child: Text(l10n.bulkView),
                      ),
                    ],
                  ],
                  const SizedBox(height: Spacing.lg),
                ],
              ),
      ),
    );
  }
}

class _ReviewQueue extends ConsumerWidget {
  const _ReviewQueue({
    required this.items,
    required this.accepting,
    required this.accepted,
    required this.onAccept,
  });
  final List<UploadItem> items;
  final bool accepting;
  final int? accepted;
  final Future<void> Function(List<String> ids) onAccept;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final garments = [
      for (final i in items) ref.watch(garmentDetailProvider(i.garmentId!)),
    ];
    final ready = <String>[
      for (final g in garments)
        if (g.valueOrNull != null &&
            g.valueOrNull!.analysisStatus == AnalysisStatus.done &&
            !g.valueOrNull!.reviewed)
          g.valueOrNull!.id,
    ];
    final working = garments
        .where((g) => g.valueOrNull?.analysisStatus.isWorking ?? true)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.bulkReviewTitle,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        Text(
          l10n.bulkReviewBody,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (working > 0)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.xs),
            child: Text(l10n.bulkWorking(working)),
          ),
        const SizedBox(height: Spacing.sm),
        for (final g in garments)
          if (g.valueOrNull != null) _Row(garment: g.valueOrNull!),
        const SizedBox(height: Spacing.sm),
        if (accepted != null)
          Semantics(liveRegion: true, child: Text(l10n.bulkAccepted(accepted!)))
        else
          FilledButton(
            onPressed: ready.isEmpty || accepting
                ? null
                : () => onAccept(ready),
            child: Text(l10n.bulkAcceptAll),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.garment});
  final Garment garment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final g = garment;
    final cover = g.cover;
    final name = garmentName(
      l10n,
      category: g.category,
      subcategory: g.subcategory,
      color: g.primaryColor,
    );
    final working = g.analysisStatus.isWorking;
    final manual = g.analysisStatus == AnalysisStatus.needsManual;
    final check = g.lowConfidenceFields.isNotEmpty && !g.reviewed;
    final status = working
        ? l10n.closetItemAnalysing
        : manual
        ? l10n.closetItemNeedsManual
        : check
        ? l10n.closetItemNeedsReview
        : l10n.bulkRowReady;
    final (pillBg, pillFg) = working
        ? (scheme.surfaceContainerHigh, scheme.onSurfaceVariant)
        : manual || check
        ? (scheme.errorContainer, scheme.onErrorContainer)
        : (scheme.secondaryContainer, scheme.onSecondaryContainer);
    void open() => context.push(ClosetRoutes.item(g.id));
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Semantics(
        button: true,
        label: l10n.closetItemLabel(name, status),
        excludeSemantics: true,
        onTap: open,
        child: Material(
          color: scheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RadiusTokens.lg),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: open,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: Spacing.minTouchTarget + 24,
              ),
              child: Padding(
                padding: const EdgeInsets.all(Spacing.sm + 2),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(RadiusTokens.md),
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child:
                            cover != null && cover.status == ImageStatus.ready
                            ? GarmentImageView(
                                imageId: cover.id,
                                url: cover.urlSmall ?? cover.urlMedium,
                                variant: 's',
                                cacheWidth: 180,
                              )
                            : ColoredBox(
                                color: scheme.surfaceContainerHighest,
                              ),
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(name, style: text.titleMedium),
                          const SizedBox(height: Spacing.xs),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: pillBg,
                                borderRadius: BorderRadius.circular(
                                  RadiusTokens.pill,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Spacing.sm + 2,
                                  vertical: 3,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (working)
                                      const Padding(
                                        padding: EdgeInsets.only(
                                          right: Spacing.xs,
                                        ),
                                        child: SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    else if (manual || check)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: Spacing.xs,
                                        ),
                                        child: Icon(
                                          Icons.flag_outlined,
                                          size: 14,
                                          color: pillFg,
                                        ),
                                      )
                                    else
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: Spacing.xs,
                                        ),
                                        child: Icon(
                                          Icons.check,
                                          size: 14,
                                          color: pillFg,
                                        ),
                                      ),
                                    Flexible(
                                      child: Text(
                                        status,
                                        style: text.labelMedium?.copyWith(
                                          color: pillFg,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
