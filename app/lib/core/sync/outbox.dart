import 'dart:async';
import 'dart:convert';

import 'package:stylist/core/network/api_exception.dart';
import 'package:stylist/core/storage/key_value_store.dart';
import 'package:uuid/uuid.dart';

class OutboxOp {
  const OutboxOp({
    required this.id,
    required this.type,
    required this.payload,
    required this.idempotencyKey,
  });

  factory OutboxOp.fromJson(Map<String, dynamic> j) => OutboxOp(
    id: j['id'] as String,
    type: j['type'] as String,
    payload: (j['payload'] as Map).cast<String, dynamic>(),
    idempotencyKey: j['key'] as String,
  );

  final String id;
  final String type;
  final Map<String, dynamic> payload;

  /// Stable across retries so the server can de-duplicate replays.
  final String idempotencyKey;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'payload': payload,
    'key': idempotencyKey,
  };
}

typedef OutboxExecutor = Future<void> Function(OutboxOp op);

/// Durable queue for mutations made while offline. Ops of the same `type` are
/// coalesced (latest snapshot wins, or maps merge) so the queue stays small.
class Outbox {
  Outbox(this._store, this._execute, {this.onError});

  static const _key = 'outbox_v1';
  final KeyValueStore _store;
  final OutboxExecutor _execute;
  final void Function(OutboxOp op, ApiException error)? onError;
  bool _flushing = false;

  List<OutboxOp> get pending {
    final raw = _store.read(_key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => OutboxOp.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> _save(List<OutboxOp> ops) => ops.isEmpty
      ? _store.remove(_key)
      : _store.write(_key, jsonEncode(ops.map((e) => e.toJson()).toList()));

  /// [merge]: shallow-merge into an existing op of the same type instead of replacing it.
  Future<void> enqueue(
    String type,
    Map<String, dynamic> payload, {
    bool merge = false,
  }) async {
    final ops = pending;
    final i = ops.indexWhere((o) => o.type == type);
    if (i >= 0) {
      ops[i] = OutboxOp(
        id: ops[i].id,
        type: type,
        payload: merge ? {...ops[i].payload, ...payload} : payload,
        idempotencyKey: const Uuid().v4(),
      );
    } else {
      ops.add(
        OutboxOp(
          id: const Uuid().v4(),
          type: type,
          payload: payload,
          idempotencyKey: const Uuid().v4(),
        ),
      );
    }
    await _save(ops);
  }

  Future<void> clear() => _store.remove(_key);

  /// Sends queued ops in order. Stops at the first connectivity failure and
  /// keeps the op; drops ops the server rejects permanently.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      while (true) {
        final ops = pending;
        if (ops.isEmpty) return;
        final op = ops.first;
        try {
          await _execute(op);
        } on ApiException catch (e) {
          final retryable =
              e.isOffline ||
              e.statusCode == null ||
              e.statusCode! >= 500 ||
              const {401, 408, 429}.contains(e.statusCode);
          if (retryable) return;
          onError?.call(op, e);
        }
        // Remove only if unchanged; a newer snapshot queued meanwhile is sent next.
        final now = pending;
        final j = now.indexWhere(
          (o) => o.id == op.id && o.idempotencyKey == op.idempotencyKey,
        );
        if (j >= 0) {
          now.removeAt(j);
          await _save(now);
        }
      }
    } finally {
      _flushing = false;
    }
  }
}
