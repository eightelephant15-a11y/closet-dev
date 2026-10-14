import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where mock mode keeps photo bytes (and where the upload queue keeps photos waiting to upload).
abstract class BlobStore {
  Future<void> put(String key, Uint8List bytes);
  Future<Uint8List?> get(String key);
  Future<bool> exists(String key);
  Future<void> delete(String key);

  /// Removes everything (sign-out / account deletion on this device).
  Future<void> clear();
}

class MemoryBlobStore implements BlobStore {
  final Map<String, Uint8List> data = {};

  @override
  Future<void> put(String key, Uint8List bytes) async => data[key] = bytes;

  @override
  Future<Uint8List?> get(String key) async => data[key];

  @override
  Future<bool> exists(String key) async => data.containsKey(key);

  @override
  Future<void> delete(String key) async => data.remove(key);

  @override
  Future<void> clear() async => data.clear();
}

/// Files under the app's support directory; survives restarts (mock mode and the upload queue).
class FileBlobStore implements BlobStore {
  FileBlobStore(this.folder);
  final String folder;
  Directory? _dir;

  Future<Directory> _root() async {
    final existing = _dir;
    if (existing != null) return existing;
    final base = await getApplicationSupportDirectory();
    final d = Directory(p.join(base.path, folder));
    if (!d.existsSync()) await d.create(recursive: true);
    return _dir = d;
  }

  Future<File> _file(String key) async => File(
    p.join(
      (await _root()).path,
      key.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_'),
    ),
  );

  @override
  Future<void> put(String key, Uint8List bytes) async =>
      (await _file(key)).writeAsBytes(bytes, flush: true);

  @override
  Future<Uint8List?> get(String key) async {
    final f = await _file(key);
    return f.existsSync() ? f.readAsBytes() : null;
  }

  @override
  Future<bool> exists(String key) async => (await _file(key)).existsSync();

  @override
  Future<void> delete(String key) async {
    final f = await _file(key);
    if (f.existsSync()) await f.delete();
  }

  @override
  Future<void> clear() async {
    final d = await _root();
    for (final e in d.listSync()) {
      if (e is File) await e.delete();
    }
  }
}
