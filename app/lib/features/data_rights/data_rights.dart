import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stylist/core/network/api_client.dart';
import 'package:stylist/core/storage/key_value_store.dart';
import 'package:stylist/features/auth/domain/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

enum ExportStatus { pending, completed, failed }

@immutable
class ExportJobInfo {
  const ExportJobInfo({required this.id, required this.status});

  factory ExportJobInfo.fromJson(Map<String, dynamic> j) => ExportJobInfo(
    id: j['id'] as String,
    status: ExportStatus.values.byName(j['status'] as String),
  );

  final String id;
  final ExportStatus status;
}

/// "Export my data": async job producing a JSON file.
abstract class ExportRepository {
  Future<ExportJobInfo> request();
  Future<ExportJobInfo> status(String id);
  Future<List<int>> download(String id);
}

class HttpExportRepository implements ExportRepository {
  HttpExportRepository(this._dio);
  final Dio _dio;

  @override
  Future<ExportJobInfo> request() async {
    final res = await guarded(
      () => _dio.post<Map<String, dynamic>>('/v1/me/export'),
    );
    return ExportJobInfo.fromJson(res.data!);
  }

  @override
  Future<ExportJobInfo> status(String id) async {
    final res = await guarded(
      () => _dio.get<Map<String, dynamic>>('/v1/me/export/$id'),
    );
    return ExportJobInfo.fromJson(res.data!);
  }

  @override
  Future<List<int>> download(String id) async {
    final res = await guarded(
      () => _dio.get<List<int>>(
        '/v1/me/export/$id/download',
        options: Options(responseType: ResponseType.bytes),
      ),
    );
    return res.data!;
  }
}

/// Builds the export from locally mocked server data; completes after
/// [pendingPolls] status checks so the polling UI is exercised.
class MockExportRepository implements ExportRepository {
  MockExportRepository(this._auth, this._store, {this.pendingPolls = 1});
  final AuthProvider _auth;
  final KeyValueStore _store;
  final int pendingPolls;
  int _polls = 0;
  int requests = 0;

  @override
  Future<ExportJobInfo> request() async {
    requests++;
    _polls = 0;
    return const ExportJobInfo(id: 'mock-export', status: ExportStatus.pending);
  }

  @override
  Future<ExportJobInfo> status(String id) async {
    _polls++;
    return ExportJobInfo(
      id: id,
      status: _polls > pendingPolls
          ? ExportStatus.completed
          : ExportStatus.pending,
    );
  }

  @override
  Future<List<int>> download(String id) async {
    final uid = _auth.currentUser?.uid;
    Object? read(String key) {
      final raw = _store.read(key);
      return raw == null ? null : jsonDecode(raw);
    }

    final users = read('mock_server_users') as Map<String, dynamic>?;
    final data = {
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'format_version': 1,
      'profile': users?[uid],
      'onboarding': read('mock_server_onboarding_$uid'),
      'preferences': {'answers': read('mock_server_prefs_$uid')},
      'consents': read('mock_server_consents_$uid'),
    };
    return utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
  }
}

abstract class FileSharer {
  Future<void> shareFile({
    required String filename,
    required List<int> bytes,
    String? mimeType,
  });
}

class SharePlusFileSharer implements FileSharer {
  @override
  Future<void> shareFile({
    required String filename,
    required List<int> bytes,
    String? mimeType,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = XFile.fromData(
      Uint8List.fromList(bytes),
      name: filename,
      mimeType: mimeType,
      path: '${dir.path}/$filename',
    );
    await SharePlus.instance.share(ShareParams(files: [file]));
  }
}

class FakeFileSharer implements FileSharer {
  final shared = <({String filename, List<int> bytes})>[];

  @override
  Future<void> shareFile({
    required String filename,
    required List<int> bytes,
    String? mimeType,
  }) async => shared.add((filename: filename, bytes: bytes));
}

abstract class UrlOpener {
  Future<void> open(String url);
}

class DeviceUrlOpener implements UrlOpener {
  @override
  Future<void> open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

class FakeUrlOpener implements UrlOpener {
  final opened = <String>[];

  @override
  Future<void> open(String url) async => opened.add(url);
}
