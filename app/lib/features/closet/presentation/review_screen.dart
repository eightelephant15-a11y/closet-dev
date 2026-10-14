import 'dart:async';
import 'dart:typed_data';

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
import 'package:stylist/features/closet/presentation/garment_fields_editor.dart';
import 'package:stylist/features/onboarding/application/onboarding_controller.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/state_views.dart';
import 'package:stylist/theme/tokens.dart';

/// Right after a photo is queued: the picture, what the AI made of it, and one-tap chips to fix it.
///
/// Works while everything is still in flight: the photo may be uploading, the AI may not have answered,
/// and the phone may be offline. Corrections made early are kept and sent as soon as the garment exists.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({required this.clientId, super.key});
  final String clientId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  /// Everything the user changed on this screen (API field names).
  final Map<String, Object?> _edits = {};

  /// Changes not yet sent to the server.
  final Map<String, Object?> _unsent = {};
  final Set<String> _reportedCorrections = {};
  Uint8List? _localPhoto;
  String? _photoKey;
  bool _saveFailed = false;
  bool _sending = false;

  Future<void> _loadLocalPhoto(UploadItem item) async {
    if (_photoKey == item.photoKey) return;
    _photoKey = item.photoKey;
    final bytes = await ref.read(queueBlobStoreProvider).get(item.photoKey);
    if (mounted && bytes != null) setState(() => _localPhoto = bytes);
  }

  void _onChanged(Map<String, Object?> changes, Garment? garment) {
    setState(() {
      _edits.addAll(changes);
      _unsent.addAll(changes);
      _saveFailed = false;
    });
    if (garment != null) {
      for (final e in changes.entries) {
        final ai = garment.aiFields?[e.key];
        if (ai != null &&
            ai.value != e.value &&
            _reportedCorrections.add(e.key)) {
          ref.read(analyticsServiceProvider).track(
            AnalyticsEvent.closetItemCorrected,
            {'field': e.key},
          );
        }
      }
      unawaited(_flush(garment.id));
    }
  }

  Future<void> _flush(String garmentId) async {
    if (_unsent.isEmpty || _sending) return;
    _sending = true;
    final batch = Map<String, Object?>.of(_unsent);
    try {
      await ref.read(garmentRepositoryProvider).patch(garmentId, batch);
      batch.forEach((k, v) {
        if (_unsent[k] == v) _unsent.remove(k);
      });
      ref.invalidate(garmentDetailProvider(garmentId));
      unawaited(ref.read(closetListProvider.notifier).refresh());
      if (mounted) setState(() => _saveFailed = false);
    } on ApiException {
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      _sending = false;
    }
    if (_unsent.isNotEmpty && mounted && !_saveFailed) {
      unawaited(_flush(garmentId));
    }
  }

  Future<void> _finish(String garmentId) async {
    await _flush(garmentId);
    if (_saveFailed) return;
    try {
      await ref.read(garmentRepositoryProvider).patch(garmentId, {
        'reviewed': true,
      });
    } on ApiException {
      if (mounted) setState(() => _saveFailed = true);
      return;
    }
    unawaited(ref.read(closetListProvider.notifier).refresh());
    ref.invalidate(closetSummaryProvider);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(ClosetRoutes.root);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = ref.watch(uploadItemsProvider);
    final item = items.valueOrNull
        ?.where((i) => i.clientId == widget.clientId)
        .firstOrNull;
    final garmentId = item?.garmentId;
    final garmentAsync = garmentId == null
        ? null
        : ref.watch(garmentDetailProvider(garmentId));
    final garment = garmentAsync?.valueOrNull;
    if (item != null) unawaited(_loadLocalPhoto(item));
    if (garmentId != null &&
        _unsent.isNotEmpty &&
        !_sending &&
        garment != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_flush(garmentId));
      });
    }

    final values = <String, Object?>{
      if (garment != null) ...editableValues(garment),
      ..._edits,
    };
    final lowConfidence = <String>{
      for (final f in garment?.lowConfidenceFields ?? const <String>[])
        if (!_edits.containsKey(f)) f,
    };
    final dept = ref.watch(
      onboardingControllerProvider.select((s) => s?.quiz.department),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reviewTitle),
        leading: IconButton(
          tooltip: l10n.close,
          icon: const Icon(Icons.close),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(ClosetRoutes.root),
        ),
      ),
      body: PageBody(
        child: item == null && garment == null
            ? (items.isLoading
                  ? const LoadingView()
                  : EmptyView(message: l10n.detailLoadFailed))
            : ListView(
                children: [
                  if (item != null) const UploadBanner(),
                  const SizedBox(height: Spacing.sm),
                  _PhotoBox(
                    local: _localPhoto,
                    garment: garment,
                    label: l10n.reviewPhoto,
                  ),
                  const SizedBox(height: Spacing.md),
                  _StatusLine(item: item, garment: garment),
                  if (_saveFailed)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        l10n.reviewSaveFailed,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: Spacing.md),
                  GarmentFieldsEditor(
                    values: values,
                    lowConfidence: lowConfidence,
                    department: dept,
                    onChanged: (c) => _onChanged(c, garment),
                  ),
                  const SizedBox(height: Spacing.sm),
                  FilledButton(
                    onPressed: garmentId == null
                        ? null
                        : () => _finish(garmentId),
                    child: Text(l10n.reviewDone),
                  ),
                  TextButton(
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go(ClosetRoutes.root),
                    child: Text(l10n.reviewSkipForNow),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PhotoBox extends StatelessWidget {
  const _PhotoBox({
    required this.local,
    required this.garment,
    required this.label,
  });
  final Uint8List? local;
  final Garment? garment;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cover = garment?.cover;
    final ready = cover != null && cover.status == ImageStatus.ready;
    return Semantics(
      image: true,
      label: label,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RadiusTokens.md),
        child: SizedBox(
          height: 240,
          width: double.infinity,
          child: ready
              ? GarmentImageView(
                  imageId: cover.id,
                  url: cover.urlLarge,
                  variant: 'l',
                  fit: BoxFit.contain,
                )
              : local != null
              ? Image.memory(
                  local!,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                )
              : ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.item, required this.garment});
  final UploadItem? item;
  final Garment? garment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final status = garment?.analysisStatus;
    final failed =
        item?.state == UploadState.failed ||
        item?.state == UploadState.rejected;
    final offline =
        item != null && item!.isActive && item!.errorCode == 'offline';
    final (text, spinner) = failed
        ? (l10n.reviewFailed, false)
        : offline
        ? (l10n.reviewWaiting, false)
        : status == AnalysisStatus.done
        ? (l10n.reviewAnalysed, false)
        : status == AnalysisStatus.needsManual
        ? (l10n.reviewManual, false)
        : (
            item != null && item!.isActive && garment == null
                ? l10n.reviewUploading
                : l10n.reviewAnalysing,
            true,
          );
    return Semantics(
      liveRegion: true,
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: spinner
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    failed ? Icons.error_outline : Icons.info_outline,
                    color: failed ? scheme.error : scheme.primary,
                  ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(child: Text(text)),
          if (failed && item != null)
            Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => unawaited(
                  ref.read(uploadQueueProvider).retry(item!.clientId),
                ),
                child: Text(l10n.uploadRetry),
              ),
            ),
        ],
      ),
    );
  }
}
