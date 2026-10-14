import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:stylist/features/closet/application/image_pipeline.dart';

/// The system camera and photo library. Fakes stand in on simulators and in CI.
abstract class ImageSourceService {
  /// The OS camera app (fallback when the guided camera is unavailable). Null if cancelled.
  Future<PickedImage?> takePhoto();

  /// Multi-select from the library, at most [limit] photos. Empty if cancelled.
  Future<List<PickedImage>> pickFromLibrary({required int limit});
}

class DeviceImageSource implements ImageSourceService {
  DeviceImageSource([ImagePicker? picker]) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  Future<PickedImage> _read(XFile f) async =>
      PickedImage(name: f.name, bytes: await f.readAsBytes());

  @override
  Future<PickedImage?> takePhoto() async {
    final f = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 90,
    );
    return f == null ? null : _read(f);
  }

  @override
  Future<List<PickedImage>> pickFromLibrary({required int limit}) async {
    final files = limit == 1
        ? [
            ?await _picker.pickImage(
              source: ImageSource.gallery,
              maxWidth: 2400,
              maxHeight: 2400,
              imageQuality: 90,
            ),
          ]
        : await _picker.pickMultiImage(
            maxWidth: 2400,
            maxHeight: 2400,
            imageQuality: 90,
            limit: limit,
          );
    return [for (final f in files.take(limit)) await _read(f)];
  }
}

/// Scripted source for tests and simulators.
class FakeImageSource implements ImageSourceService {
  FakeImageSource({List<PickedImage>? camera, List<PickedImage>? library})
    : _camera = Queue.of(camera ?? []),
      library = [...?library];

  final Queue<PickedImage> _camera;
  final List<PickedImage> library;
  int libraryCalls = 0;
  int lastLimit = 0;

  @override
  Future<PickedImage?> takePhoto() async =>
      _camera.isEmpty ? null : _camera.removeFirst();

  @override
  Future<List<PickedImage>> pickFromLibrary({required int limit}) async {
    libraryCalls++;
    lastLimit = limit;
    return library.take(limit).toList();
  }
}

/// How bright the scene is, from the camera preview.
enum LightingLevel { tooDark, ok, tooBright }

@immutable
class LightingHint {
  const LightingHint(this.level, this.meanLuminance);

  factory LightingHint.fromLuminance(double mean) => LightingHint(
    mean < 60
        ? LightingLevel.tooDark
        : mean > 205
        ? LightingLevel.tooBright
        : LightingLevel.ok,
    mean,
  );

  final LightingLevel level;
  final double meanLuminance;
}

class CameraUnavailable implements Exception {
  const CameraUnavailable(this.reason);
  final String reason;
}

/// The guided in-app camera: live preview, brightness hint, capture.
abstract class CameraService {
  Future<void> initialize();
  Widget buildPreview();
  Future<PickedImage> capture();
  Stream<LightingHint> get lighting;
  Future<void> dispose();
}

class FakeCameraService implements CameraService {
  FakeCameraService({this.photos = const [], this.failInit = false});
  final List<PickedImage> photos;
  final bool failInit;
  final _lighting = StreamController<LightingHint>.broadcast();
  int captured = 0;
  bool disposed = false;

  void emit(LightingHint hint) => _lighting.add(hint);

  @override
  Future<void> initialize() async {
    if (failInit) throw const CameraUnavailable('no camera');
  }

  @override
  Widget buildPreview() =>
      const ColoredBox(color: Color(0xFF444444), child: SizedBox.expand());

  @override
  Future<PickedImage> capture() async => photos[captured++ % photos.length];

  @override
  Stream<LightingHint> get lighting => _lighting.stream;

  @override
  Future<void> dispose() async {
    disposed = true;
    await _lighting.close();
  }
}
