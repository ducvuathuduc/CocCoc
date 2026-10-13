import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../domain/learning_models.dart';
import 'lesson_audio_catalog.g.dart';
import 'lesson_audio_io_stub.dart'
    if (dart.library.io) 'lesson_audio_io.dart'
    as platform;
import 'lesson_image_io_stub.dart'
    if (dart.library.io) 'lesson_image_io.dart'
    as net;

/// Where a resolved clip's bytes live.
sealed class LessonAudioSource {
  const LessonAudioSource();
}

/// A clip shipped with the app: [path] is relative to `assets/`
/// (`lesson_audio/<fileId>.aac`, the form audio players take).
final class BundledLessonAudio extends LessonAudioSource {
  const BundledLessonAudio(this.path);
  final String path;

  @override
  bool operator ==(Object other) =>
      other is BundledLessonAudio && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

/// A verified clip in the on-device cache (absolute file path).
final class CachedLessonAudio extends LessonAudioSource {
  const CachedLessonAudio(this.path);
  final String path;

  @override
  bool operator ==(Object other) =>
      other is CachedLessonAudio && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

/// Resolves a content audio clip ([LessonAudio]) to something a player can
/// open, mirroring LessonImageStore:
///
/// 1. A clip the app ships under `assets/lesson_audio/<fileId>.aac`
///    ([bundledLessonAudio]) whose sha256 equals the bundle's hash is used
///    directly (mock content has no hash and always uses the shipped clip).
/// 2. Otherwise (API mode) the clip is read from the on-device cache keyed by
///    its sha256, or downloaded from the public `learning-assets` bucket,
///    verified against the bundle hash and cached. A failed download falls
///    back to a shipped clip with the same fileId; with neither the exercise
///    keeps its text (every audio item has a text alternative).
class LessonAudioStore {
  LessonAudioStore({
    required this.endpoint,
    required this.projectId,
    LessonAudioFetcher? fetcher,
    LessonAudioCache? cache,
    Map<String, String>? bundled,
  }) : fetcher = fetcher ?? net.fetchLessonImage,
       cache = cache ?? platform.LessonAudioDiskCache(),
       bundled = bundled ?? bundledLessonAudio;

  final String endpoint;
  final String projectId;
  final LessonAudioFetcher fetcher;
  final LessonAudioCache cache;
  final Map<String, String> bundled;
  final Map<String, Future<LessonAudioSource?>> _pending = {};

  static const bucketId = 'learning-assets';
  static const maxBytes = 2 * 1024 * 1024;

  /// Public file view URL (published files carry `read(Role.any())`).
  Uri urlFor(String fileId) => Uri.parse(
    '$endpoint/storage/buckets/$bucketId/files/'
    '${Uri.encodeComponent(fileId)}/view?project=$projectId',
  );

  /// Asset path (relative to `assets/`) when the app ships these exact bytes.
  String? bundledAsset(LessonAudio clip) {
    final hash = bundled[clip.fileId];
    if (hash == null) return null;
    if (clip.sha256 != null && clip.sha256 != hash) return null;
    return 'lesson_audio/${clip.fileId}.aac';
  }

  /// The shipped word clip for a tile text (`a.w.<slug>.n`), if any.
  LessonAudio? bundledWord(String text) {
    final id = 'a.w.${wordAudioSlug(text)}.n';
    return bundled.containsKey(id) ? LessonAudio(id) : null;
  }

  Future<LessonAudioSource?> resolve(LessonAudio clip) {
    final asset = bundledAsset(clip);
    if (asset != null) return Future.value(BundledLessonAudio(asset));
    final hash = clip.sha256;
    if (hash == null) return Future.value(null);
    // The callback must not return the removed future.
    return _pending[hash] ??= _load(clip.fileId, hash).whenComplete(() {
      _pending.remove(hash);
    });
  }

  Future<LessonAudioSource?> _load(String fileId, String hash) async {
    final cached = await cache.read(hash);
    if (cached != null && _matches(cached.bytes, hash)) {
      return CachedLessonAudio(cached.path);
    }
    final bytes = await fetcher(urlFor(fileId), maxBytes);
    if (bytes != null && _matches(bytes, hash)) {
      final path = await cache.write(hash, bytes);
      if (path != null) return CachedLessonAudio(path);
    }
    final fallback = bundledAsset(LessonAudio(fileId));
    return fallback == null ? null : BundledLessonAudio(fallback);
  }

  /// Warms the cache for the clips of a lesson (best effort, sequential so a
  /// slow network is not flooded).
  Future<void> prefetch(Iterable<LessonAudio> clips) async {
    for (final clip in clips) {
      await resolve(clip);
    }
  }

  static bool _matches(Uint8List bytes, String hash) =>
      sha256.convert(bytes).toString() == hash;
}

/// Downloads [url] (null on any failure or when larger than [maxBytes]).
typedef LessonAudioFetcher = Future<Uint8List?> Function(Uri url, int maxBytes);

/// A cached clip: its bytes (re-verified on read) and the file to play.
class CachedClip {
  const CachedClip(this.path, this.bytes);
  final String path;
  final Uint8List bytes;
}

/// Content-addressed clip cache (key = sha256 of the bytes). Players need a
/// file, so [write] returns the path it stored (null when nothing can be
/// stored, e.g. widget tests or web).
abstract class LessonAudioCache {
  Future<CachedClip?> read(String sha256);
  Future<String?> write(String sha256, Uint8List bytes);
}

final lessonAudioStoreProvider = Provider<LessonAudioStore>((ref) {
  final config = ref.watch(appConfigProvider);
  return LessonAudioStore(
    endpoint: config.appwriteEndpoint,
    projectId: config.appwriteProjectId,
  );
});
