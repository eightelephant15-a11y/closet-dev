import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// A photo straight from the camera or library.
@immutable
class PickedImage {
  const PickedImage({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

/// A photo ready to upload: oriented, resized, metadata-free JPEG.
@immutable
class ProcessedPhoto {
  const ProcessedPhoto({
    required this.bytes,
    required this.filename,
    required this.width,
    required this.height,
    this.contentType = 'image/jpeg',
  });
  final Uint8List bytes;
  final String filename;
  final String contentType;
  final int width;
  final int height;
}

/// A crop as fractions of the image (0..1), origin top-left.
@immutable
class CropRect {
  const CropRect(this.left, this.top, this.right, this.bottom);
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get area => (right - left) * (bottom - top);

  @override
  bool operator ==(Object other) =>
      other is CropRect &&
      left == other.left &&
      top == other.top &&
      right == other.right &&
      bottom == other.bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

class ImageProcessingException implements Exception {
  const ImageProcessingException(this.message);
  final String message;
  @override
  String toString() => 'ImageProcessingException: $message';
}

abstract class ImageProcessor {
  /// Orients, optionally crops, resizes and re-encodes (which also drops EXIF/GPS).
  Future<ProcessedPhoto> process(PickedImage image, {CropRect? crop});

  /// A crop around the garment if the photo has a clear subject on a plain background.
  Future<CropRect?> suggestCrop(PickedImage image);
}

/// Picture-taking helpers that do not depend on a device: easy to test.
abstract final class PhotoMath {
  /// Longest side of a stored photo (the server keeps up to 2048 too).
  static const maxSide = 2048;
  static const jpegQuality = 85;

  /// Mean brightness (0..255) of a luma plane, sampled for speed.
  static double meanLuminance(Uint8List luma, {int step = 16}) {
    if (luma.isEmpty) return 0;
    var sum = 0;
    var n = 0;
    for (var i = 0; i < luma.length; i += step) {
      sum += luma[i];
      n++;
    }
    return sum / n;
  }

  /// A subject-on-plain-background bounding box, or null when there is no clear subject.
  ///
  /// The background level is the median of the border pixels; pixels differing from it by more than
  /// [threshold] belong to the subject.
  static CropRect? suggestCrop(
    Uint8List luma,
    int width,
    int height, {
    int threshold = 28,
  }) {
    if (width < 8 || height < 8 || luma.length < width * height) return null;
    final border = <int>[];
    for (var x = 0; x < width; x++) {
      border
        ..add(luma[x])
        ..add(luma[(height - 1) * width + x]);
    }
    for (var y = 0; y < height; y++) {
      border
        ..add(luma[y * width])
        ..add(luma[y * width + width - 1]);
    }
    border.sort();
    final background = border[border.length ~/ 2];
    var minX = width;
    var minY = height;
    var maxX = -1;
    var maxY = -1;
    var count = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if ((luma[y * width + x] - background).abs() > threshold) {
          count++;
          minX = math.min(minX, x);
          maxX = math.max(maxX, x);
          minY = math.min(minY, y);
          maxY = math.max(maxY, y);
        }
      }
    }
    if (count < width * height * 0.02 || maxX < 0) return null;
    const margin = 0.05;
    final rect = CropRect(
      ((minX / width) - margin).clamp(0, 1),
      ((minY / height) - margin).clamp(0, 1),
      (((maxX + 1) / width) + margin).clamp(0, 1),
      (((maxY + 1) / height) + margin).clamp(0, 1),
    );
    // Already (almost) the whole frame: nothing worth suggesting.
    return rect.area > 0.88 ? null : rect;
  }
}

/// Pure-Dart implementation (runs off the UI thread via [compute]).
class DartImageProcessor implements ImageProcessor {
  const DartImageProcessor();

  @override
  Future<ProcessedPhoto> process(PickedImage image, {CropRect? crop}) =>
      compute(_process, _Job(image.name, image.bytes, crop));

  @override
  Future<CropRect?> suggestCrop(PickedImage image) =>
      compute(_suggest, image.bytes);
}

class _Job {
  const _Job(this.name, this.bytes, this.crop);
  final String name;
  final Uint8List bytes;
  final CropRect? crop;
}

ProcessedPhoto _process(_Job job) {
  var decoded = img.decodeImage(job.bytes);
  if (decoded == null) {
    throw const ImageProcessingException(
      'This photo format is not supported. Try a JPEG or PNG.',
    );
  }
  decoded = img.bakeOrientation(
    decoded,
  ); // applies the EXIF rotation, then the tag is gone
  final crop = job.crop;
  if (crop != null) {
    final x = (crop.left * decoded.width).round();
    final y = (crop.top * decoded.height).round();
    final w = ((crop.right - crop.left) * decoded.width).round().clamp(
      1,
      decoded.width - x,
    );
    final h = ((crop.bottom - crop.top) * decoded.height).round().clamp(
      1,
      decoded.height - y,
    );
    decoded = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
  }
  if (math.max(decoded.width, decoded.height) > PhotoMath.maxSide) {
    decoded = decoded.width >= decoded.height
        ? img.copyResize(
            decoded,
            width: PhotoMath.maxSide,
            interpolation: img.Interpolation.average,
          )
        : img.copyResize(
            decoded,
            height: PhotoMath.maxSide,
            interpolation: img.Interpolation.average,
          );
  }
  final bytes = Uint8List.fromList(
    img.encodeJpg(decoded, quality: PhotoMath.jpegQuality),
  );
  final base = job.name.contains('.')
      ? job.name.substring(0, job.name.lastIndexOf('.'))
      : job.name;
  return ProcessedPhoto(
    bytes: bytes,
    filename: '$base.jpg',
    width: decoded.width,
    height: decoded.height,
  );
}

CropRect? _suggest(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final small = img.copyResize(
    img.bakeOrientation(decoded),
    width: 96,
    interpolation: img.Interpolation.average,
  );
  final gray = img.grayscale(small);
  final luma = Uint8List(gray.width * gray.height);
  var i = 0;
  for (final p in gray) {
    luma[i++] = p.r.toInt();
  }
  return PhotoMath.suggestCrop(luma, gray.width, gray.height);
}
