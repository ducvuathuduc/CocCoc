import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../domain/learning_models.dart';
import 'lesson_image_catalog.g.dart';
import 'lesson_image_io_stub.dart'
    if (dart.library.io) 'lesson_image_io.dart'
    as platform;

/// Resolves a content word illustration ([LessonImage]) to pixels.
///
/// 1. The app ships every v2 illustration under
///    `assets/lesson_images/<fileId>.webp` ([bundledLessonImages]); a bundled
///    file whose sha256 equals the bundle's hash is used directly (mock
///    content has no hash and always uses the bundled file).
/// 2. Otherwise (API mode, art published after this build) the file is read
///    from the on-device cache keyed by its sha256, or downloaded from the
///    public `learning-assets` bucket, verified against the bundle hash and
///    cached. If that fails, the bundled drawing of the same word is used;
///    with neither, the tile keeps its word label (every option has one).
class LessonImageStore {
  LessonImageStore({
    required this.endpoint,
    required this.projectId,
    LessonImageFetcher? fetcher,
    LessonImageCache? cache,
    Map<String, String>? bundled,
  }) : fetcher = fetcher ?? platform.fetchLessonImage,
       cache = cache ?? platform.LessonImageDiskCache(),
       bundled = bundled ?? bundledLessonImages;

  final String endpoint;
  final String projectId;
  final LessonImageFetcher fetcher;
  final LessonImageCache cache;
  final Map<String, String> bundled;
  final Map<String, Uint8List> _memory = {};
  final Map<String, Future<Uint8List?>> _pending = {};

  static const bucketId = 'learning-assets';
  static const maxBytes = 5 * 1024 * 1024;

  /// Public file view URL (published files carry `read(Role.any())`).
  Uri urlFor(String fileId) => Uri.parse(
    '$endpoint/storage/buckets/$bucketId/files/'
    '${Uri.encodeComponent(fileId)}/view?project=$projectId',
  );

  /// Asset path when the app ships these exact bytes, else `null`.
  String? bundledAsset(LessonImage image) {
    final hash = bundled[image.fileId];
    if (hash == null) return null;
    if (image.sha256 != null && image.sha256 != hash) return null;
    return 'assets/lesson_images/${image.fileId}.webp';
  }

  /// Whether [image] can be shown without asking the server for its hash.
  bool canShow(LessonImage image) =>
      image.sha256 != null || bundledAsset(image) != null;

  /// Verified bytes of a non-bundled image (memory, disk, then network).
  Future<Uint8List?> load(LessonImage image) {
    final hash = image.sha256;
    if (hash == null) return Future.value(null);
    final hit = _memory[hash];
    if (hit != null) return Future.value(hit);
    // The callback must not return the removed future (whenComplete would
    // wait on itself).
    return _pending[hash] ??= _load(image.fileId, hash).whenComplete(() {
      _pending.remove(hash);
    });
  }

  Future<Uint8List?> _load(String fileId, String hash) async {
    var bytes = await cache.read(hash);
    if (bytes == null || !_matches(bytes, hash)) {
      bytes = await fetcher(urlFor(fileId), maxBytes);
      if (bytes == null || !_matches(bytes, hash)) return null;
      await cache.write(hash, bytes);
    }
    return _memory[hash] = bytes;
  }

  static bool _matches(Uint8List bytes, String hash) =>
      sha256.convert(bytes).toString() == hash;

  /// [ImageProvider] for [image]: the bundled asset, or verified bytes; when
  /// the published file cannot be fetched or verified, the illustration the
  /// app ships for the same word (an older drawing beats an empty tile).
  Future<ImageProvider?> resolve(LessonImage image) async {
    final asset = bundledAsset(image);
    if (asset != null) return AssetImage(asset);
    final bytes = await load(image);
    if (bytes != null) return MemoryImage(bytes);
    final fallback = bundledAsset(LessonImage(image.fileId));
    return fallback == null ? null : AssetImage(fallback);
  }
}

/// Downloads [url] (null on any failure or when larger than [maxBytes]).
typedef LessonImageFetcher = Future<Uint8List?> Function(Uri url, int maxBytes);

/// Content-addressed byte cache (key = sha256 of the bytes).
abstract class LessonImageCache {
  Future<Uint8List?> read(String sha256);
  Future<void> write(String sha256, Uint8List bytes);
}

final lessonImageStoreProvider = Provider<LessonImageStore>((ref) {
  final config = ref.watch(appConfigProvider);
  return LessonImageStore(
    endpoint: config.appwriteEndpoint,
    projectId: config.appwriteProjectId,
  );
});
