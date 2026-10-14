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
    final problem = _cameraProblem;
    if (problem != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(problem, textAlign: TextAlign.center),
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
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_cameraReady)
                ClipRect(child: _camera!.buildPreview())
              else
                const Center(child: CircularProgressIndicator()),
              // Outline to line the garment up with.
              Semantics(
                label: l10n.captureFlip,
                child: const ExcludeSemantics(
                  child: CustomPaint(painter: _OutlinePainter(Colors.white)),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          color: hintBad
              ? scheme.errorContainer
              : scheme.surfaceContainerHighest,
          padding: const EdgeInsets.all(Spacing.md),
          child: Semantics(
            liveRegion: true,
            child: Text(
              hintText,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: hintBad ? scheme.onErrorContainer : scheme.onSurface,
              ),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(Spacing.sm),
            child: Text(_error!, style: TextStyle(color: scheme.error)),
          ),
        Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _fromLibrary,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(l10n.captureLibrary),
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: l10n.captureTake,
                excludeSemantics: true,
                onTap: _cameraReady ? _shoot : null,
                child: InkResponse(
                  onTap: _cameraReady ? _shoot : null,
                  radius: 44,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary,
                      border: Border.all(color: scheme.onSurface, width: 4),
                    ),
                    child: Icon(Icons.camera_alt, color: scheme.onPrimary),
                  ),
                ),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _previewBody(AppLocalizations l10n) {
    final image = _picked!;
    final crop = _crop;
    return Column(
      children: [
        Expanded(
          child: Semantics(
            label: l10n.captureReview,
            image: true,
            child: LayoutBuilder(
              builder: (context, box) => ColoredBox(
                color: Colors.black,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _aspect,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          image.bytes,
                          fit: BoxFit.fill,
                          excludeFromSemantics: true,
                        ),
                        if (crop != null && _useCrop)
                          ExcludeSemantics(
                            child: CustomPaint(painter: _CropPainter(crop)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (crop != null)
          SwitchListTile(
            title: Text(l10n.captureCrop),
            value: _useCrop,
            onChanged: (v) => setState(() => _useCrop = v),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(Spacing.sm),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _retake,
                  child: Text(l10n.captureRetake),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: _use,
                  child: Text(l10n.captureUse),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
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
