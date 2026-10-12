import 'dart:typed_data';

import 'lesson_image_store.dart';

/// Web build: no dart:io download/cache; the view falls back to the public
/// URL (browser HTTP cache) for images the app does not ship.
Future<Uint8List?> fetchLessonImage(Uri url, int maxBytes) async => null;

class LessonImageDiskCache implements LessonImageCache {
  @override
  Future<Uint8List?> read(String sha256) async => null;

  @override
  Future<void> write(String sha256, Uint8List bytes) async {}
}
