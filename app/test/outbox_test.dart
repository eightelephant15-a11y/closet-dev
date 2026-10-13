import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/core/network/api_exception.dart';
import 'package:stylist/core/storage/key_value_store.dart';
import 'package:stylist/core/sync/outbox.dart';

void main() {
  test(
    'queues offline, flushes in order once online, survives restart',
    () async {
      final store = MemoryKeyValueStore();
      final sent = <String>[];
      var online = false;
      Future<void> exec(OutboxOp op) async {
        if (!online) throw const ApiException.offline();
        sent.add('${op.type}:${op.payload['v']}');
      }

      var box = Outbox(store, exec);
      await box.enqueue('a', {'v': 1});
      await box.enqueue('b', {'v': 2});
      await box.flush();
      expect(sent, isEmpty);
      expect(box.pending, hasLength(2));

      box = Outbox(store, exec); // "restart"
      online = true;
      await box.flush();
      expect(sent, ['a:1', 'b:2']);
      expect(box.pending, isEmpty);
    },
  );

  test('coalesces same-type ops (latest wins) and merges when asked', () async {
    final box = Outbox(MemoryKeyValueStore(), (_) async {});
    await box.enqueue('put', {'v': 1});
    await box.enqueue('put', {'v': 2});
    expect(box.pending.single.payload['v'], 2);
    await box.enqueue('patch', {'a': 1}, merge: true);
    await box.enqueue('patch', {'b': 2}, merge: true);
    expect(box.pending.last.payload, {'a': 1, 'b': 2});
  });

  test('permanent server rejection drops the op; transient keeps it', () async {
    final errors = <String>[];
    var failWith = const ApiException(
      code: 'bad',
      message: '',
      statusCode: 422,
    );
    final box = Outbox(
      MemoryKeyValueStore(),
      (_) async => throw failWith,
      onError: (op, e) => errors.add(e.code),
    );
    await box.enqueue('x', {});
    await box.flush();
    expect(box.pending, isEmpty);
    expect(errors, ['bad']);

    failWith = const ApiException(code: 'boom', message: '', statusCode: 503);
    await box.enqueue('x', {});
    await box.flush();
    expect(box.pending, hasLength(1));
  });

  test('a snapshot queued during a flush is still delivered', () async {
    final store = MemoryKeyValueStore();
    final sent = <int>[];
    late Outbox box;
    var first = true;
    box = Outbox(store, (op) async {
      if (first) {
        first = false;
        await box.enqueue('put', {'v': 2}); // newer state arrives mid-flight
      }
      sent.add(op.payload['v'] as int);
    });
    await box.enqueue('put', {'v': 1});
    await box.flush();
    expect(sent, [1, 2]);
    expect(box.pending, isEmpty);
  });
}
