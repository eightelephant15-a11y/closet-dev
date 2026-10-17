import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/core/analytics/analytics_event.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/features/closet/application/closet_providers.dart';
import 'package:stylist/features/data_rights/data_rights.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/atelier.dart';
import 'package:stylist/shared/widgets/state_views.dart';
import 'package:stylist/theme/tokens.dart';

enum _Phase { idle, preparing, ready, failed }

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({
    this.pollInterval = const Duration(seconds: 2),
    super.key,
  });
  final Duration pollInterval;

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  _Phase _phase = _Phase.idle;
  late String _jobId;
  bool _sharing = false;

  Future<void> _request() async {
    setState(() => _phase = _Phase.preparing);
    try {
      final repo = ref.read(exportRepositoryProvider);
      var job = await repo.request();
      _jobId = job.id;
      for (var i = 0; i < 60 && job.status == ExportStatus.pending; i++) {
        await Future<void>.delayed(widget.pollInterval);
        if (!mounted) return;
        job = await repo.status(job.id);
      }
      if (!mounted) return;
      setState(
        () => _phase = job.status == ExportStatus.completed
            ? _Phase.ready
            : _Phase.failed,
      );
    } on Object {
      if (mounted) setState(() => _phase = _Phase.failed);
    }
  }

  Future<void> _share() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sharing = true);
    try {
      final bytes = await ref.read(exportRepositoryProvider).download(_jobId);
      // The server sends a ZIP (data + photos); older/mock exports are plain JSON.
      final isZip = bytes.length > 3 && bytes[0] == 0x50 && bytes[1] == 0x4B;
      await ref
          .read(fileSharerProvider)
          .shareFile(
            filename: isZip ? 'my-data.zip' : 'my-data.json',
            bytes: bytes,
            mimeType: isZip ? 'application/zip' : 'application/json',
          );
      ref.read(analyticsServiceProvider).track(AnalyticsEvent.dataExported);
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportShared)));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final summary = ref.watch(closetSummaryProvider).valueOrNull;
    final step = switch (_phase) {
      _Phase.idle => 0,
      _Phase.preparing => 1,
      _Phase.ready => 2,
      _Phase.failed => 1,
    };
    final steps = [
      l10n.exportStepRequest,
      l10n.exportStepPrepare,
      l10n.exportStepDownload,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.exportTitle)),
      body: PageBody(
        child: ListView(
          children: [
            Eyebrow(l10n.exportEyebrow),
            const SizedBox(height: Spacing.xs),
            Text(
              l10n.exportBody,
              style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: Spacing.md),
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
                        selected: i == step,
                        child: Container(
                          alignment: Alignment.center,
                          constraints: const BoxConstraints(
                            minHeight: Spacing.minTouchTarget - 8,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.xs,
                            vertical: Spacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: i == step
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
                                color: i == step
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
            if (summary != null) ...[
              const SizedBox(height: Spacing.md),
              NoteCard(
                icon: Icons.inventory_2_outlined,
                title: l10n.exportContentsTitle,
                child: Text(
                  l10n.exportContentsBody(summary.total, summary.archived),
                ),
              ),
            ],
            const SizedBox(height: Spacing.lg),
            switch (_phase) {
              _Phase.idle => SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _request,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: Text(l10n.exportRequest),
                ),
              ),
              _Phase.preparing => Column(
                children: [
                  const LoadingView(),
                  const SizedBox(height: Spacing.sm),
                  Semantics(
                    liveRegion: true,
                    child: Text(l10n.exportPreparing),
                  ),
                ],
              ),
              _Phase.ready => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(l10n.exportReady, style: text.titleMedium),
                  ),
                  const SizedBox(height: Spacing.md),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _sharing ? null : _share,
                      child: Text(l10n.exportShare),
                    ),
                  ),
                ],
              ),
              _Phase.failed => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      l10n.exportFailed,
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  FilledButton(onPressed: _request, child: Text(l10n.retry)),
                ],
              ),
            },
            const SizedBox(height: Spacing.lg),
          ],
        ),
      ),
    );
  }
}
