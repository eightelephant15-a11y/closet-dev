import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/core/analytics/analytics_event.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/features/data_rights/data_rights.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
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
      await ref
          .read(fileSharerProvider)
          .shareFile(
            filename: 'my-data.json',
            bytes: bytes,
            mimeType: 'application/json',
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.exportTitle)),
      body: PageBody(
        child: ListView(
          children: [
            Text(l10n.exportBody, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: Spacing.lg),
            switch (_phase) {
              _Phase.idle => FilledButton(
                onPressed: _request,
                child: Text(l10n.exportRequest),
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
                children: [
                  Semantics(liveRegion: true, child: Text(l10n.exportReady)),
                  const SizedBox(height: Spacing.md),
                  FilledButton(
                    onPressed: _sharing ? null : _share,
                    child: Text(l10n.exportShare),
                  ),
                ],
              ),
              _Phase.failed => Column(
                children: [
                  Semantics(liveRegion: true, child: Text(l10n.exportFailed)),
                  const SizedBox(height: Spacing.md),
                  FilledButton(onPressed: _request, child: Text(l10n.retry)),
                ],
              ),
            },
          ],
        ),
      ),
    );
  }
}
