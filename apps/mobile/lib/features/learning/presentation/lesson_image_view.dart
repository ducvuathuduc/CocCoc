import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/lesson_image_store.dart';
import '../domain/learning_models.dart';

/// Square word illustration for a picture tile ([LessonImageStore]).
/// Reserves its [size] while loading so the tile never changes height.
class LessonImageView extends ConsumerStatefulWidget {
  const LessonImageView(this.image, {required this.size, super.key});

  final LessonImage image;
  final double size;

  @override
  ConsumerState<LessonImageView> createState() => _LessonImageViewState();
}

class _LessonImageViewState extends ConsumerState<LessonImageView> {
  Future<ImageProvider?>? _future;
  LessonImage? _for;

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(lessonImageStoreProvider);
    final asset = store.bundledAsset(widget.image);
    if (asset != null) return _image(AssetImage(asset));
    if (_for != widget.image) {
      _for = widget.image;
      _future = store.resolve(widget.image);
    }
    return FutureBuilder<ImageProvider?>(
      future: _future,
      builder: (context, snapshot) {
        final provider = snapshot.data;
        if (provider != null) return _image(provider);
        if (snapshot.connectionState == ConnectionState.done && kIsWeb) {
          return _image(
            NetworkImage(store.urlFor(widget.image.fileId).toString()),
          );
        }
        return SizedBox.square(dimension: widget.size);
      },
    );
  }

  Widget _image(ImageProvider provider) => Image(
    image: provider,
    width: widget.size,
    height: widget.size,
    fit: BoxFit.contain,
    gaplessPlayback: true,
    excludeFromSemantics: true,
    errorBuilder: (_, _, _) => SizedBox.square(dimension: widget.size),
  );
}
