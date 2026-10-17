import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stylist/core/analytics/analytics_event.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/features/closet/application/closet_providers.dart';
import 'package:stylist/features/closet/application/image_pipeline.dart';
import 'package:stylist/features/closet/application/image_source.dart';
import 'package:stylist/features/closet/presentation/closet_routes.dart';
import 'package:stylist/features/onboarding/domain/onboarding_state.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/theme/tokens.dart';

enum _Step { camera, preview, processing }

/// Guided capture: live preview with an outline and a lighting hint, then a quick preview with an
/// optional crop suggestion. "Use this photo" queues the upload and opens the review screen right away,
/// so the user is already correcting details while the photo uploads and the AI looks at it.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({this.startInLibrary = false, super.key});

  /// Open the photo library straight away instead of the camera.
  final bool startInLibrary;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  CameraService? _camera;
  StreamSubscription<LightingHint>? _light;
  LightingHint? _hint;
  _Step _step = _Step.camera;
  bool _cameraReady = false;
  String? _cameraProblem;
  PickedImage? _picked;
  CropRect? _crop;
  double _aspect = 3 / 4;
  bool _useCrop = true;
  String? _error;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    // Over the item limit? Say so before the user does any work.
    final summary = await ref
        .read(closetSummaryProvider.future)
        .catchError(
          (_) => ref.read(closetSummaryProvider).valueOrNull!,
        );
    if (!mounted) return;
    if (summary.remaining <= 0) {
      ref.read(analyticsServiceProvider).track(
        AnalyticsEvent.closetLimitReached,
        {
          'limit': summary.limit,
          'used': summary.used,
        },
      );
      context.pushReplacement(ClosetRoutes.upgrade);
      return;
    }
    if (widget.startInLibrary) {
      await _fromLibrary();
      if (mounted && _picked == null) context.pop();
      return;
    }
    await _startCamera();
  }

  Future<void> _startCamera() async {
    final permissions = ref.read(permissionsServiceProvider);
    if (!await permissions.isGranted(PermissionKind.camera)) {
      // The Phase 1 primer already asked; here we only ask if it never did.
      final outcome = await permissions.request(PermissionKind.camera);
      if (outcome != PermissionOutcome.granted) {
        if (mounted) {
          setState(
            () =>
                _cameraProblem = AppLocalizations.of(context).capturePermission,
          );
        }
        return;
      }
    }
    final camera = ref.read(cameraFactoryProvider)();
    try {
      await camera.initialize();
    } on CameraUnavailable {
      await camera.dispose();
      if (mounted) {
        setState(
          () =>
              _cameraProblem = AppLocalizations.of(context).captureUnavailable,
        );
      }
      return;
    }
    if (!mounted) {
      await camera.dispose();
      return;
    }
    _light = camera.lighting.listen((h) {
      if (mounted && h.level != _hint?.level) setState(() => _hint = h);
    });
    setState(() {
      _camera = camera;
      _cameraReady = true;
    });
  }

  @override
  void dispose() {
    unawaited(_light?.cancel());
    unawaited(_camera?.dispose());
    super.dispose();
  }

  void _trackStart(String source) {
    if (_started) return;
    _started = true;
    ref.read(analyticsServiceProvider).track(
      AnalyticsEvent.closetItemCaptureStarted,
      {'source': source},
    );
  }

  Future<void> _shoot() async {
    final camera = _camera;
    if (camera == null) return;
    _trackStart('camera');
    try {
      await _show(await camera.capture());
    } on Object {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).captureBad);
      }
    }
  }

  Future<void> _fromLibrary() async {
    final picks = await ref
        .read(imageSourceServiceProvider)
        .pickFromLibrary(limit: 1);
    if (picks.isEmpty || !mounted) return;
    _trackStart('library');
    await _show(picks.first);
  }

  Future<void> _show(PickedImage image) async {
    setState(() {
      _picked = image;
      _crop = null;
      _useCrop = true;
      _error = null;
      _step = _Step.preview;
    });
    final crop = await ref.read(imageProcessorProvider).suggestCrop(image);
    var aspect = _aspect;
    try {
      final decoded = await decodeImageFromList(image.bytes);
      aspect = decoded.width / decoded.height;
      decoded.dispose();
    } on Object {
      // keep the previous aspect; the preview still shows
    }
    if (mounted && _picked == image) {
      setState(() {
        _crop = crop;
        _aspect = aspect;
      });
    }
  }

  void _retake() => setState(() {
    _picked = null;
    _step = _Step.camera;
    _error = null;
  });

  Future<void> _use() async {
    final image = _picked;
    if (image == null) return;
    setState(() => _step = _Step.processing);
    try {
      final photo = await ref
          .read(imageProcessorProvider)
          .process(image, crop: _useCrop ? _crop : null);
      final id = await ref.read(uploadQueueProvider).enqueue(photo);
      if (mounted) context.pushReplacement(ClosetRoutes.review(id));
    } on ImageProcessingException {
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context).captureBad;
          _step = _Step.preview;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.captureTitle),
        leading: IconButton(
          tooltip: l10n.close,
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: switch (_step) {
          _Step.camera => _cameraBody(l10n),
          _Step.preview => _previewBody(l10n),
          _Step.processing => Center(
            child: Semantics(
              liveRegion: true,
              label: l10n.captureProcessing,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: Spacing.md),
                  ExcludeSemantics(child: Text(l10n.captureProcessing)),
                ],
              ),
            ),
          ),
        },
      ),
    );
  }

  Widget _cameraBody(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final problem = _cameraProblem;
    if (problem != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.no_photography_outlined,
                  size: 56,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: Spacing.md),
              Text(problem, textAlign: TextAlign.center, style: text.bodyLarge),
              const SizedBox(height: Spacing.md),
              FilledButton(
                onPressed: _fromLibrary,
                child: Text(l10n.captureLibrary),
              ),
              if (problem == l10n.capturePermission)
                TextButton(
                  onPressed: ref.read(permissionsServiceProvider).openSettings,
                  child: Text(l10n.permOpenSettings),
                ),
            ],
          ),
        ),
      );
    }
    final hint = _hint;
    final hintText = switch (hint?.level) {
      LightingLevel.tooDark => l10n.lightTooDark,
      LightingLevel.tooBright => l10n.lightTooBright,
      LightingLevel.ok => l10n.lightOk,
      null => l10n.captureHint,
    };
    final hintBad = hint != null && hint.level != LightingLevel.ok;
    final hintGood = hint != null && hint.level == LightingLevel.ok;
    final bulkOn =
        ref.watch(remoteConfigProvider).valueOrNull?.closetBulkAddEnabled ??
        true;
    const panelText = _panelText;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.xs,
        Spacing.md,
        Spacing.md,
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(RadiusTokens.xl),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: _stage,
                    child: _cameraReady
                        ? ClipRect(child: _camera!.buildPreview())
                        : const Center(child: CircularProgressIndicator()),
                  ),
                  // Outline to line the garment up.
                  Semantics(
                    label: l10n.captureFlip,
                    child: const ExcludeSemantics(
                      child: CustomPaint(
                        painter: _OutlinePainter(Colors.white),
                      ),
                    ),
                  ),
                  Positioned(
                    left: Spacing.sm + 4,
                    right: Spacing.sm + 4,
                    top: Spacing.sm + 4,
                    child: Semantics(
                      liveRegion: true,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: hintBad
                              ? scheme.errorContainer
                              : hintGood
                              ? scheme.secondaryContainer
                              : scheme.surface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(
                            RadiusTokens.pill,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.md,
                            vertical: Spacing.sm,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ExcludeSemantics(
                                child: Icon(
                                  hintBad
                                      ? Icons.light_mode_outlined
                                      : hintGood
                                      ? Icons.check_circle_outline
                                      : Icons.wb_twilight_outlined,
                                  size: 18,
                                  color: hintBad
                                      ? scheme.onErrorContainer
                                      : scheme.primary,
                                ),
                              ),
                              const SizedBox(width: Spacing.sm),
                              Flexible(
                                child: Text(
                                  hintText,
                                  style: text.labelLarge?.copyWith(
                                    color: hintBad
                                        ? scheme.onErrorContainer
                                        : scheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: Text(_error!, style: TextStyle(color: scheme.error)),
            ),
          const SizedBox(height: Spacing.sm + 4),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm + 4,
            ),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(RadiusTokens.xl),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _PanelButton(
                    icon: Icons.photo_library_outlined,
                    label: l10n.captureLibraryShort,
                    semantic: l10n.captureLibrary,
                    color: panelText,
                    onTap: _fromLibrary,
                  ),
                ),
                Semantics(
                  button: true,
                  label: l10n.captureTake,
                  excludeSemantics: true,
                  onTap: _cameraReady ? _shoot : null,
                  child: InkResponse(
                    onTap: _cameraReady ? _shoot : null,
                    radius: 48,
                    child: Container(
                      width: 72,
                      height: 72,
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: panelText,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.primaryContainer,
                          border: Border.all(
                            color: _panel,
                            width: 3,
                          ),
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: bulkOn
                      ? _PanelButton(
                          icon: Icons.collections_outlined,
                          label: l10n.captureBulkShort,
                          semantic: l10n.closetAddMany,
                          color: panelText,
                          onTap: () =>
                              context.pushReplacement(ClosetRoutes.bulk),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewBody(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final image = _picked!;
    final crop = _crop;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.xs,
        Spacing.md,
        Spacing.md,
      ),
      child: Column(
        children: [
          Expanded(
            child: Semantics(
              label: l10n.captureReview,
              image: true,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(RadiusTokens.xl),
                child: ColoredBox(
                  color: _stage,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.sm + 4),
                      child: AspectRatio(
                        aspectRatio: _aspect,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                RadiusTokens.md,
                              ),
                              child: Image.memory(
                                image.bytes,
                                fit: BoxFit.fill,
                                excludeFromSemantics: true,
                              ),
                            ),
                            if (crop != null && _useCrop)
                              ExcludeSemantics(
                                child: CustomPaint(
                                  painter: _CropPainter(crop),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (crop != null) ...[
            const SizedBox(height: Spacing.sm + 4),
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(RadiusTokens.lg),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: Spacing.xs,
                ),
                title: Text(
                  l10n.captureCrop,
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(l10n.captureCropBody),
                value: _useCrop,
                onChanged: (v) => setState(() => _useCrop = v),
              ),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: Text(_error!, style: TextStyle(color: scheme.error)),
            ),
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: scheme.surfaceContainerLowest,
                      foregroundColor: scheme.primary,
                    ),
                    onPressed: _retake,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.captureRetake),
                  ),
                ),
              ),
              const SizedBox(width: Spacing.sm + 4),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _use,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            l10n.captureUse,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        const ExcludeSemantics(
                          child: Icon(Icons.arrow_forward, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The camera stage and control panel stay dark in both themes (like any camera app).
const Color _stage = Color(0xFF1B1816);
const Color _panel = Color(0xFF2F2A28);
const Color _panelText = Color(0xFFF3EDE4);

/// A labelled icon button on the dark control panel (>= 48dp).
class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.icon,
    required this.label,
    required this.semantic,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String semantic;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semantic,
    excludeSemantics: true,
    onTap: onTap,
    child: InkWell(
      borderRadius: BorderRadius.circular(RadiusTokens.md),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: Spacing.minTouchTarget + 16,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: Spacing.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OutlinePainter extends CustomPainter {
  const _OutlinePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.7;
    final h = size.height * 0.7;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: size.center(Offset.zero), width: w, height: h),
      const Radius.circular(24),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_OutlinePainter old) => old.color != color;
}

/// Draws the suggested crop over the (letter-boxed) photo.
class _CropPainter extends CustomPainter {
  const _CropPainter(this.crop);
  final CropRect crop;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTRB(
      crop.left * size.width,
      crop.top * size.height,
      crop.right * size.width,
      crop.bottom * size.height,
    );
    canvas.drawRect(
      r,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.crop != crop;
}
