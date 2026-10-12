import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'lesson_image_store.dart';

/// dart:io download of a public content image (Android/iOS/desktop/tests).
Future<Uint8List?> fetchLessonImage(Uri url, int maxBytes) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client
        .getUrl(url)
        .timeout(const Duration(seconds: 10));
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return null;
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(const Duration(seconds: 15))) {
      builder.add(chunk);
      if (builder.length > maxBytes) return null;
    }
    return builder.takeBytes();
  } on Object {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// `<application support>/lesson_images/<sha256>.webp`; memory-only when the
/// platform has no support directory (e.g. widget tests).
class LessonImageDiskCache implements LessonImageCache {
  Future<Directory?>? _dir;

  Future<Directory?> _directory() => _dir ??= () async {
    try {
      final base = await getApplicationSupportDirectory();
      return await Directory('${base.path}/lesson_images')
          .create(recursive: true);
    } on Object {
      return null;
    }
  }();

  @override
  Future<Uint8List?> read(String sha256) async {
    final dir = await _directory();
    if (dir == null) return null;
    final file = File('${dir.path}/$sha256.webp');
    try {
      return await file.exists() ? await file.readAsBytes() : null;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(String sha256, Uint8List bytes) async {
    final dir = await _directory();
    if (dir == null) return;
    final file = File('${dir.path}/$sha256.webp');
    final temp = File('${file.path}.part');
    try {
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(file.path);
    } on Object {
      // Best effort: the image is still served from memory.
    }
  }
}
