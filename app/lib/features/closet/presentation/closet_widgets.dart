import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/features/closet/application/closet_providers.dart';
import 'package:stylist/features/closet/application/upload_queue.dart';
import 'package:stylist/features/closet/domain/garment.dart';
import 'package:stylist/features/closet/domain/taxonomy.dart';
import 'package:stylist/features/closet/domain/taxonomy_labels.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/atelier.dart';
import 'package:stylist/theme/tokens.dart';

/// "Navy Jeans", or just the type / category when the AI has not filled the rest in yet.
String garmentName(
  AppLocalizations l10n, {
  String? category,
  String? subcategory,
  String? color,
}) {
  final type = subcategory != null
      ? l10n.taxSubcategory(subcategory)
      : category != null
      ? l10n.taxCategory(category)
      : null;
  if (type == null) return l10n.closetItemAnalysing;
  return color == null ? type : l10n.garmentName(l10n.taxColor(color), type);
}

String availabilityLabel(AppLocalizations l10n, Availability a) => switch (a) {
  Availability.available => l10n.availabilityAvailable,
  Availability.laundry => l10n.availabilityLaundry,
  Availability.lent => l10n.availabilityLent,
  Availability.repair => l10n.availabilityRepair,
};

/// A small in-memory cache in front of the disk cache: scrolling back up never re-decodes from disk.
class _MemoryImages {
  static final _lru = <String, Uint8List>{};
  static const _max = 160;

  static Uint8List? get(String key) {
    final v = _lru.remove(key);
    if (v != null) _lru[key] = v;
    return v;
  }

  static void put(String key, Uint8List bytes) {
    _lru[key] = bytes;
    while (_lru.length > _max) {
      _lru.remove(_lru.keys.first);
    }
  }

  static void clear() => _lru.clear();
}

void clearImageMemoryCache() => _MemoryImages.clear();

/// A garment picture. The cache key is the image id + size, not the (changing) signed URL.
class GarmentImageView extends ConsumerStatefulWidget {
  const GarmentImageView({
    required this.imageId,
    required this.url,
    this.variant = 'm',
    this.fit = BoxFit.cover,
    this.cacheWidth,
    super.key,
  });

  final String? imageId;
  final String? url;
  final String variant;
  final BoxFit fit;
  final int? cacheWidth;

  @override
  ConsumerState<GarmentImageView> createState() => _GarmentImageViewState();
}

class _GarmentImageViewState extends ConsumerState<GarmentImageView> {
  Uint8List? _bytes;
  bool _failed = false;

  String? get _key =>
      widget.imageId == null ? null : '${widget.imageId}_${widget.variant}';

  @override
  void initState() {
    super.initState();
    _bytes = _key == null ? null : _MemoryImages.get(_key!);
    if (_bytes == null) unawaited(_load());
  }

  @override
  void didUpdateWidget(GarmentImageView old) {
    super.didUpdateWidget(old);
    if (old.imageId != widget.imageId || old.variant != widget.variant) {
      _bytes = _key == null ? null : _MemoryImages.get(_key!);
      _failed = false;
      if (_bytes == null) unawaited(_load());
    }
  }

  Future<void> _load() async {
    final id = widget.imageId;
    if (id == null) return;
    final bytes = await ref
        .read(imageBytesSourceProvider)
        .load(imageId: id, variant: widget.variant, url: widget.url);
    if (!mounted) return;
    if (bytes == null) {
      setState(() => _failed = true);
      return;
    }
    _MemoryImages.put('${id}_${widget.variant}', bytes);
    setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: widget.fit,
        cacheWidth: widget.cacheWidth,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) =>
            ColoredBox(color: scheme.surfaceContainerHighest),
      );
    }
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: _failed
          ? Icon(Icons.broken_image_outlined, color: scheme.outline)
          : null,
    );
  }
}

/// The picture for a grid row: bundled asset for sample garments, cached download otherwise.
class GarmentThumb extends StatelessWidget {
  const GarmentThumb({required this.garment, this.cacheWidth, super.key});
  final GarmentSummary garment;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final asset = garment.sampleAsset;
    if (garment.isSample && asset != null) {
      return Image.asset(
        'assets/sample_closet/$asset.webp',
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        excludeFromSemantics: true,
      );
    }
    return GarmentImageView(
      imageId: garment.imageVersion,
      url: garment.thumbUrl,
      cacheWidth: cacheWidth,
    );
  }
}

/// A coloured dot for a palette colour (decorative; the colour name is always spoken too).
class ColourDot extends StatelessWidget {
  const ColourDot(this.colourId, {this.size = 20, super.key});
  final String colourId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Taxonomy.instance.colorById(colourId)?.color ?? Colors.grey;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

String uploadStateLabel(AppLocalizations l10n, UploadState s) => switch (s) {
  UploadState.queued => l10n.uploadStateQueued,
  UploadState.creating ||
  UploadState.uploading ||
  UploadState.completing => l10n.uploadStateWorking,
  UploadState.done => l10n.uploadStateDone,
  UploadState.failed => l10n.uploadStateFailed,
  UploadState.rejected => l10n.uploadStateRejected,
};

String uploadErrorLabel(AppLocalizations l10n, String? code) => switch (code) {
  'file_too_large' => l10n.uploadErrFileTooLarge,
  'unsupported_media' || 'image_invalid' => l10n.uploadErrUnsupported,
  'item_limit_reached' => l10n.uploadErrLimit,
  _ => l10n.uploadErrGeneric,
};

/// Shows queued / uploading / failed photos. Tap to open the details sheet. Hidden when all is well.
class UploadBanner extends ConsumerWidget {
  const UploadBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(uploadItemsProvider).valueOrNull ?? const [];
    final active = items.where((i) => i.isActive).toList();
    final problems = items
        .where(
          (i) =>
              i.state == UploadState.failed || i.state == UploadState.rejected,
        )
        .toList();
    if (active.isEmpty && problems.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final waiting =
        active.isNotEmpty && active.every((i) => i.errorCode == 'offline');
    final text = problems.isNotEmpty && active.isEmpty
        ? l10n.uploadBannerFailed(problems.length)
        : waiting
        ? l10n.uploadBannerWaiting
        : l10n.uploadBannerUploading(active.length);
    final scheme = Theme.of(context).colorScheme;
    final isProblem = problems.isNotEmpty && active.isEmpty;
    return Semantics(
      liveRegion: true,
      button: true,
      label: text,
      child: Material(
        color: isProblem ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(RadiusTokens.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(RadiusTokens.md),
          onTap: () => showUploadSheet(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: Spacing.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: isProblem
                        ? Icon(
                            Icons.error_outline,
                            color: scheme.onErrorContainer,
                          )
                        : waiting
                        ? Icon(
                            Icons.cloud_off_outlined,
                            color: scheme.onSecondaryContainer,
                          )
                        : const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Text(
                        text,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: isProblem
                              ? scheme.onErrorContainer
                              : scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showUploadSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const UploadSheet(),
    );

class UploadSheet extends ConsumerWidget {
  const UploadSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final items = ref.watch(uploadItemsProvider).valueOrNull ?? const [];
    final queue = ref.read(uploadQueueProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            0,
            Spacing.lg,
            Spacing.lg,
          ),
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.uploadSheetTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: Spacing.md),
            for (var i = 0; i < items.length; i++)
              _UploadRow(index: i + 1, item: items[i], queue: queue),
            NoteCard(
              icon: Icons.lock_outline,
              child: Text(l10n.uploadPrivacyNote),
            ),
            const SizedBox(height: Spacing.md),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.uploadDone),
              ),
            ),
            SizedBox(
              height: Spacing.xs,
              child: ColoredBox(color: scheme.surface),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadRow extends ConsumerWidget {
  const _UploadRow({
    required this.index,
    required this.item,
    required this.queue,
  });
  final int index;
  final UploadItem item;
  final UploadQueue queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final state = uploadStateLabel(l10n, item.state);
    final problem =
        item.state == UploadState.failed || item.state == UploadState.rejected;
    final percent = (item.progress * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Semantics(
        container: true,
        label: l10n.uploadItemLabel(index, state),
        child: Container(
          padding: const EdgeInsets.all(Spacing.sm + 4),
          decoration: BoxDecoration(
            color: problem
                ? scheme.errorContainer.withValues(alpha: 0.6)
                : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(RadiusTokens.lg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ExcludeSemantics(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(RadiusTokens.md),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: _QueuedThumb(photoKey: item.photoKey),
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Text(
                            item.filename,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall,
                          ),
                        ),
                        ExcludeSemantics(
                          child: Text(
                            problem
                                ? uploadErrorLabel(l10n, item.errorCode)
                                : state,
                            style: text.bodySmall?.copyWith(
                              color: problem
                                  ? scheme.onErrorContainer
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item.state == UploadState.uploading)
                    Text(
                      '$percent%',
                      style: text.labelLarge?.copyWith(color: scheme.primary),
                    ),
                ],
              ),
              if (item.state == UploadState.uploading) ...[
                const SizedBox(height: Spacing.sm),
                Semantics(
                  label: l10n.uploadProgressLabel(percent),
                  child: ExcludeSemantics(
                    child: LinearProgressIndicator(
                      value: item.progress,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
              if (problem) ...[
                const SizedBox(height: Spacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => unawaited(queue.remove(item.clientId)),
                      child: Text(l10n.uploadRemove),
                    ),
                    if (item.state == UploadState.failed) ...[
                      const SizedBox(width: Spacing.sm),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: scheme.surfaceContainerLowest,
                          foregroundColor: scheme.primary,
                        ),
                        onPressed: () => unawaited(queue.retry(item.clientId)),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(l10n.uploadRetry),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The photo waiting in the upload queue (read from the local queue store).
class _QueuedThumb extends ConsumerStatefulWidget {
  const _QueuedThumb({required this.photoKey});
  final String photoKey;

  @override
  ConsumerState<_QueuedThumb> createState() => _QueuedThumbState();
}

class _QueuedThumbState extends ConsumerState<_QueuedThumb> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    unawaited(
      ref.read(queueBlobStoreProvider).get(widget.photoKey).then((b) {
        if (mounted && b != null) setState(() => _bytes = b);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = _bytes;
    return b == null
        ? ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          )
        : Image.memory(b, fit: BoxFit.cover, cacheWidth: 156);
  }
}
