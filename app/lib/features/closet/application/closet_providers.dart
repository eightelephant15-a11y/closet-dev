import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/core/analytics/analytics_event.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/features/closet/application/device_camera.dart';
import 'package:stylist/features/closet/application/image_pipeline.dart';
import 'package:stylist/features/closet/application/image_source.dart';
import 'package:stylist/features/closet/application/upload_queue.dart';
import 'package:stylist/features/closet/data/blob_store.dart';
import 'package:stylist/features/closet/data/http_garment_repository.dart';
import 'package:stylist/features/closet/data/image_bytes_source.dart';
import 'package:stylist/features/closet/data/mock_closet.dart';
import 'package:stylist/features/closet/domain/closet_item.dart';
import 'package:stylist/features/closet/domain/closet_item_adapter.dart';
import 'package:stylist/features/closet/domain/closet_meter.dart';
import 'package:stylist/features/closet/domain/closet_query.dart';
import 'package:stylist/features/closet/domain/garment.dart';
import 'package:stylist/features/closet/domain/garment_repository.dart';
import 'package:stylist/features/config/domain/remote_config.dart';
import 'package:stylist/features/onboarding/application/onboarding_controller.dart';

// ---- storage and services (overridden by fakes in tests) -------------------------------------------

/// Photos waiting in the upload queue. Overridden with a memory store in tests.
final queueBlobStoreProvider = Provider<BlobStore>(
  (ref) => FileBlobStore('upload_queue'),
);

/// Mock mode's pretend object storage.
final mockServerBlobStoreProvider = Provider<BlobStore>(
  (ref) => FileBlobStore('mock_server_blobs'),
);

/// Downloaded pictures (thumbnails etc.), keyed by image id and size.
final imageCacheStoreProvider = Provider<BlobStore>(
  (ref) => FileBlobStore('image_cache'),
);

final imageSourceServiceProvider = Provider<ImageSourceService>(
  (ref) => DeviceImageSource(),
);

final imageProcessorProvider = Provider<ImageProcessor>(
  (ref) => const DartImageProcessor(),
);

/// Opens a fresh camera each time the capture screen is shown.
final cameraFactoryProvider = Provider<CameraService Function()>(
  (ref) => DeviceCameraService.new,
);

// ---- repository ------------------------------------------------------------------------------------

final _config = Provider<RemoteConfig>(
  (ref) => ref.watch(remoteConfigProvider).valueOrNull ?? const RemoteConfig(),
);

final mockClosetBackendProvider = Provider<MockClosetBackend>((ref) {
  final user = ref.watch(authProviderProvider).currentUser?.uid ?? 'guest';
  return MockClosetBackend(
    store: ref.watch(keyValueStoreProvider),
    blobs: ref.watch(mockServerBlobStoreProvider),
    userKey: user,
    itemLimit: () => ref.read(_config).closetItemLimitFree,
    bulkEnabled: () => ref.read(_config).closetBulkAddEnabled,
    department: () => ref.read(onboardingControllerProvider)?.quiz.department,
  );
});

final garmentRepositoryProvider = Provider<GarmentRepository>((ref) {
  return ref.watch(appConfigProvider).useMock
      ? ref.watch(mockClosetBackendProvider)
      : HttpGarmentRepository(ref.watch(dioProvider));
});

final uploadTransportProvider = Provider<UploadTransport>((ref) {
  return ref.watch(appConfigProvider).useMock
      ? ref.watch(mockClosetBackendProvider)
      : DioUploadTransport();
});

final imageBytesSourceProvider = Provider<ImageBytesSource>((ref) {
  return ref.watch(appConfigProvider).useMock
      ? MockImageBytesSource(ref.watch(mockClosetBackendProvider))
      : HttpImageBytesSource(ref.watch(imageCacheStoreProvider));
});

// ---- upload queue ----------------------------------------------------------------------------------

final uploadQueueProvider = Provider<UploadQueue>((ref) {
  final analytics = ref.watch(analyticsServiceProvider);
  final queue =
      UploadQueue(
          repository: ref.watch(garmentRepositoryProvider),
          transport: ref.watch(uploadTransportProvider),
          store: ref.watch(keyValueStoreProvider),
          blobs: ref.watch(queueBlobStoreProvider),
        )
        ..onUploaded = (item) {
          analytics.track(AnalyticsEvent.closetItemUploaded, {
            'source': item.batchId == null ? 'single' : 'bulk',
            'attempts': item.attempts + 1,
            'bytes': item.sizeBytes,
          });
          ref.invalidate(closetSummaryProvider);
          unawaited(ref.read(closetListProvider.notifier).refresh());
        }
        ..onFailed = (item) {
          if (item.errorCode == 'item_limit_reached') {
            analytics.track(AnalyticsEvent.closetLimitReached, {
              'limit': ref.read(_config).closetItemLimitFree,
              'used': ref.read(_config).closetItemLimitFree,
            });
          }
        };
  unawaited(queue.restore().then((_) => queue.resume()));
  ref.onDispose(() => unawaited(queue.dispose()));
  return queue;
});

/// Live view of the queue for banners and the progress sheet.
final uploadItemsProvider = StreamProvider<List<UploadItem>>((ref) async* {
  final q = ref.watch(uploadQueueProvider);
  await q.restore();
  yield q.items;
  yield* q.changes;
});

// ---- closet data -----------------------------------------------------------------------------------

final closetQueryProvider = StateProvider<ClosetQuery>(
  (ref) => const ClosetQuery(),
);

class ClosetListState {
  const ClosetListState({
    this.items = const [],
    this.total = 0,
    this.nextCursor,
    this.loadingMore = false,
  });
  final List<GarmentSummary> items;
  final int total;
  final String? nextCursor;
  final bool loadingMore;

  bool get hasMore => nextCursor != null;

  /// Any item the server is still working on (drives gentle polling).
  bool get hasPending => items.any((g) => g.analysisStatus.isWorking);
}

class ClosetListNotifier extends AutoDisposeAsyncNotifier<ClosetListState> {
  Timer? _poll;

  @override
  Future<ClosetListState> build() async {
    final query = ref.watch(closetQueryProvider);
    ref.onDispose(() => _poll?.cancel());
    final page = await ref.read(garmentRepositoryProvider).list(query);
    final s = ClosetListState(
      items: page.items,
      total: page.total,
      nextCursor: page.nextCursor,
    );
    _schedulePoll(s);
    return s;
  }

  void _schedulePoll(ClosetListState s) {
    _poll?.cancel();
    if (s.hasPending) {
      _poll = Timer(const Duration(seconds: 3), () => unawaited(refresh()));
    }
  }

  /// Reloads the first page(s) without clearing the screen.
  Future<void> refresh() async {
    final query = ref.read(closetQueryProvider);
    final keep = state.valueOrNull?.items.length ?? 0;
    try {
      final repo = ref.read(garmentRepositoryProvider);
      var page = await repo.list(query);
      final items = [...page.items];
      while (items.length < keep && page.nextCursor != null) {
        page = await repo.list(query, cursor: page.nextCursor);
        items.addAll(page.items);
      }
      final s = ClosetListState(
        items: items,
        total: page.total,
        nextCursor: page.nextCursor,
      );
      state = AsyncData(s);
      _schedulePoll(s);
    } on Object {
      // Keep what is on screen; pull-to-refresh retries.
    }
  }

  Future<void> loadMore() async {
    final s = state.valueOrNull;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(
      ClosetListState(
        items: s.items,
        total: s.total,
        nextCursor: s.nextCursor,
        loadingMore: true,
      ),
    );
    try {
      final page = await ref
          .read(garmentRepositoryProvider)
          .list(ref.read(closetQueryProvider), cursor: s.nextCursor);
      state = AsyncData(
        ClosetListState(
          items: [...s.items, ...page.items],
          total: page.total,
          nextCursor: page.nextCursor,
        ),
      );
    } on Object {
      state = AsyncData(
        ClosetListState(
          items: s.items,
          total: s.total,
          nextCursor: s.nextCursor,
        ),
      );
    }
  }
}

final closetListProvider =
    AutoDisposeAsyncNotifierProvider<ClosetListNotifier, ClosetListState>(
      ClosetListNotifier.new,
    );

final AutoDisposeFutureProvider<ClosetSummary> closetSummaryProvider =
    FutureProvider.autoDispose<ClosetSummary>(
      (ref) => ref.watch(garmentRepositoryProvider).summary(),
    );

final AutoDisposeFutureProvider<Entitlements> entitlementsProvider =
    FutureProvider.autoDispose<Entitlements>(
      (ref) => ref.watch(garmentRepositoryProvider).entitlements(),
    );

/// Completeness meter for the current closet (counts only wearable, available items).
final AutoDisposeProvider<AsyncValue<ClosetMeter>> closetMeterProvider =
    Provider.autoDispose<AsyncValue<ClosetMeter>>((
      ref,
    ) {
      return ref.watch(closetSummaryProvider).whenData((s) {
        return ClosetMeter.of(
          SlotCounts.fromCategoryCounts(s.availableCounts.byCategory),
        );
      });
    });

/// Garment ids whose analysis result has already been reported (once per garment per app run).
final _analysedReported = <String>{};

/// One garment, refreshed every few seconds while the AI is still working on it.
final AutoDisposeFutureProviderFamily<Garment, String> garmentDetailProvider =
    FutureProvider.autoDispose.family<Garment, String>((
      ref,
      id,
    ) async {
      final g = await ref.watch(garmentRepositoryProvider).get(id);
      if (g.analysisStatus.isWorking) {
        final t = Timer(const Duration(seconds: 2), ref.invalidateSelf);
        ref.onDispose(t.cancel);
      } else if (!g.isSample && _analysedReported.add(id)) {
        final conf = [
          for (final f in g.aiFields?.values ?? const <AiField>[]) f.confidence,
        ];
        ref.read(analyticsServiceProvider).track(
          AnalyticsEvent.closetItemAnalysed,
          {
            'status': g.analysisStatus == AnalysisStatus.done
                ? 'done'
                : 'needs_manual',
            'latency_ms': DateTime.now()
                .toUtc()
                .difference(g.createdAt)
                .inMilliseconds
                .clamp(0, 3600000),
            if (conf.isNotEmpty) ...{
              'confidence_avg': double.parse(
                (conf.reduce((a, b) => a + b) / conf.length).toStringAsFixed(2),
              ),
              'confidence_min': conf.reduce((a, b) => a < b ? a : b),
            },
            'low_confidence_count': g.lowConfidenceFields.length,
          },
        );
      }
      return g;
    });

/// The wearable closet as recommendation input (first-items unlock rule and the Phase 1 first outfit).
/// Pages through the whole closet; fine for the first-run flow, which starts from zero.
final closetItemsProvider = FutureProvider<List<ClosetItem>>((ref) async {
  final repo = ref.watch(garmentRepositoryProvider);
  final out = <ClosetItem>[];
  String? cursor;
  do {
    final page = await repo.list(
      const ClosetQuery(),
      cursor: cursor,
      limit: 100,
    );
    for (final g in page.items) {
      final item = closetItemFromSummary(g);
      if (item != null) out.add(item);
    }
    cursor = page.nextCursor;
  } while (cursor != null);
  return out;
});

/// Forgets everything the closet keeps on this device (sign-out, account deletion).
Future<void> wipeLocalCloset(Ref ref) async {
  await ref.read(uploadQueueProvider).clearAll();
  if (ref.read(appConfigProvider).useMock) {
    await ref.read(mockClosetBackendProvider).wipe();
  }
  await ref.read(imageCacheStoreProvider).clear();
  ref
    ..invalidate(closetListProvider)
    ..invalidate(closetSummaryProvider)
    ..invalidate(closetItemsProvider)
    ..invalidate(entitlementsProvider);
}
