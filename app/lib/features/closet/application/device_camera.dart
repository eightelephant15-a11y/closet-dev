import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:stylist/features/closet/application/image_pipeline.dart';
import 'package:stylist/features/closet/application/image_source.dart';

/// The real camera (back lens). UNVERIFIED on a device: written against the `camera` package API and
/// exercised through [CameraService]; every screen is tested with [FakeCameraService].
class DeviceCameraService implements CameraService {
  CameraController? _controller;
  final _lighting = StreamController<LightingHint>.broadcast();
  DateTime _lastSample = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Future<void> initialize() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw const CameraUnavailable('This device has no camera.');
    }
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      back,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );
    try {
      await controller.initialize();
    } on CameraException catch (e) {
      throw CameraUnavailable(e.description ?? e.code);
    }
    _controller = controller;
    await controller.startImageStream(_onFrame);
  }

  void _onFrame(CameraImage frame) {
    final now = DateTime.now();
    if (now.difference(_lastSample).inMilliseconds < 600 ||
        _lighting.isClosed) {
      return;
    }
    _lastSample = now;
    // yuv420: plane 0 is luminance. bgra8888: average the colour channels of sampled pixels.
    final plane = frame.planes.first.bytes;
    final mean = frame.format.group == ImageFormatGroup.yuv420
        ? PhotoMath.meanLuminance(plane)
        : _bgraMean(plane);
    _lighting.add(LightingHint.fromLuminance(mean));
  }

  double _bgraMean(List<int> bytes) {
    var sum = 0.0;
    var n = 0;
    for (var i = 0; i + 2 < bytes.length; i += 64) {
      sum += 0.114 * bytes[i] + 0.587 * bytes[i + 1] + 0.299 * bytes[i + 2];
      n++;
    }
    return n == 0 ? 0 : sum / n;
  }

  @override
  Widget buildPreview() => CameraPreview(_controller!);

  @override
  Future<PickedImage> capture() async {
    final c = _controller!;
    if (c.value.isStreamingImages) await c.stopImageStream();
    final file = await c.takePicture();
    final bytes = await file.readAsBytes();
    if (!c.value.isStreamingImages) await c.startImageStream(_onFrame);
    return PickedImage(name: file.name, bytes: bytes);
  }

  @override
  Stream<LightingHint> get lighting => _lighting.stream;

  @override
  Future<void> dispose() async {
    await _lighting.close();
    await _controller?.dispose();
  }
}
