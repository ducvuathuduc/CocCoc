import 'dart:typed_data';

import 'package:cocenglish/features/learning/data/lesson_image_catalog.g.dart';
import 'package:cocenglish/features/learning/data/lesson_image_store.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/learning/presentation/lesson_image_view.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryCache implements LessonImageCache {
  final Map<String, Uint8List> files = {};
  @override
  Future<Uint8List?> read(String sha256) async => files[sha256];
  @override
  Future<void> write(String sha256, Uint8List bytes) async =>
      files[sha256] = bytes;
}

void main() {
  final bytes = Uint8List.fromList(List.generate(64, (i) => i));
  final hash = sha256.convert(bytes).toString();

  LessonImageStore store({
    required List<Uri> calls,
    Uint8List? served,
    MemoryCache? cache,
  }) => LessonImageStore(
    endpoint: 'https://sgp.cloud.appwrite.io/v1',
    projectId: 'p1',
    cache: cache ?? MemoryCache(),
    fetcher: (url, max) async {
      calls.add(url);
      return served;
    },
  );

  test('bundled illustration with the manifest hash is used offline', () async {
    final calls = <Uri>[];
    final s = store(calls: calls);
    final image = LessonImage('i.u2.cat', bundledLessonImages['i.u2.cat']);
    expect(s.bundledAsset(image), 'assets/lesson_images/i.u2.cat.webp');
    expect(s.bundledAsset(const LessonImage('i.u2.cat')), isNotNull);
    expect(await s.resolve(image), isA<AssetImage>());
    expect(calls, isEmpty);
    expect(bundledLessonImages, hasLength(110));
  });

  test(
    'a changed hash downloads from learning-assets, verifies and caches',
    () async {
      final calls = <Uri>[];
      final cache = MemoryCache();
      final s = store(calls: calls, served: bytes, cache: cache);
      final image = LessonImage('i.u2.cat', hash);
      expect(s.bundledAsset(image), isNull, reason: 'bundled bytes differ');
      final provider = await s.resolve(image);
      expect(provider, isA<MemoryImage>());
      expect((provider! as MemoryImage).bytes, bytes);
      expect(
        calls.single.toString(),
        'https://sgp.cloud.appwrite.io/v1/storage/buckets/learning-assets/files/i.u2.cat/view?project=p1',
      );
      expect(cache.files[hash], bytes);

      // Cached by hash: a new store reads the disk cache, no network.
      final again = <Uri>[];
      final s2 = store(calls: again, cache: cache);
      expect(await s2.load(image), bytes);
      expect(again, isEmpty);
    },
  );

  test('bytes that do not match the bundle hash are rejected', () async {
    final calls = <Uri>[];
    final cache = MemoryCache();
    final s = store(
      calls: calls,
      served: Uint8List.fromList([1, 2, 3]),
      cache: cache,
    );
    expect(await s.resolve(LessonImage('i.u9.new', hash)), isNull);
    final stale = await s.resolve(LessonImage('i.u9.red', hash));
    expect(
      (stale! as AssetImage).assetName,
      'assets/lesson_images/i.u9.red.webp',
      reason: 'unverifiable download falls back to the shipped drawing',
    );
    expect(cache.files, isEmpty);
    expect(await s.resolve(const LessonImage('i.u9.unknown')), isNull);
    expect(
      calls,
      hasLength(2),
      reason:
          'one try per hashed image; no hash, nothing to verify: no download',
    );
  });

  testWidgets(
    'LessonImageView shows the bundled file, or the verified download',
    (tester) async {
      final calls = <Uri>[];
      final s = store(calls: calls, served: bytes);
      Future<void> pump(LessonImage image) => tester.pumpWidget(
        ProviderScope(
          overrides: [lessonImageStoreProvider.overrideWithValue(s)],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: LessonImageView(image, size: 120)),
          ),
        ),
      );
      await pump(const LessonImage('i.u3.apple'));
      final bundled = tester.widget<Image>(find.byType(Image));
      expect(
        (bundled.image as AssetImage).assetName,
        'assets/lesson_images/i.u3.apple.webp',
      );
      expect(
        tester.getSize(find.byType(LessonImageView)),
        const Size(120, 120),
      );

      await pump(LessonImage('i.u3.apple', hash));
      await tester.runAsync(() => s.load(LessonImage('i.u3.apple', hash)));
      await tester.pump();
      final downloaded = tester.widget<Image>(find.byType(Image));
      expect((downloaded.image as MemoryImage).bytes, bytes);
      expect(
        tester.getSize(find.byType(LessonImageView)),
        const Size(120, 120),
      );
    },
  );
}
