import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ArtRegion {
  const ArtRegion(this.file, this.source);
  final String file;
  final Rect source;
}

// Original source PNGs remain untouched. Only these illustration/icon regions
// are painted; text, cards, buttons and interaction are native Flutter widgets.
abstract final class ReferenceArtRegions {
  static const splashFace = ArtRegion('01', Rect.fromLTWH(330, 1060, 520, 348));
  static const splashWordmark = ArtRegion(
    '01',
    Rect.fromLTWH(310, 2225, 560, 150),
  );
  static const welcomeDuo = ArtRegion('02', Rect.fromLTWH(402, 720, 370, 365));
  static const wordmark = ArtRegion('02', Rect.fromLTWH(315, 1170, 555, 135));
  static const waving = ArtRegion('03', Rect.fromLTWH(400, 1306, 365, 394));
  static const excited = ArtRegion('04', Rect.fromLTWH(390, 1300, 410, 415));
  static const questionDuo = ArtRegion('05', Rect.fromLTWH(48, 350, 287, 354));
  static const building = ArtRegion('07', Rect.fromLTWH(414, 874, 370, 463));
  static const phoneWidget = ArtRegion('15', Rect.fromLTWH(152, 885, 875, 930));
  static const writing = ArtRegion('20', Rect.fromLTWH(380, 1300, 445, 425));
  static const book = ArtRegion('19', Rect.fromLTWH(128, 819, 177, 216));
  static const compass = ArtRegion('19', Rect.fromLTWH(110, 1205, 215, 215));
  static const loginDuo = ArtRegion(
    'login-07',
    Rect.fromLTWH(435, 312, 315, 365),
  );
  static const successDuo = ArtRegion(
    'login-17',
    Rect.fromLTWH(440, 1430, 315, 490),
  );
  static const google = ArtRegion('login-03', Rect.fromLTWH(276, 1681, 72, 72));
  static const facebook = ArtRegion(
    'login-03',
    Rect.fromLTWH(245, 1870, 78, 78),
  );
  static const apple = ArtRegion('login-03', Rect.fromLTWH(308, 2057, 68, 82));
  static const hiddenEye = ArtRegion(
    'login-03',
    Rect.fromLTWH(984, 548, 84, 64),
  );
  static const flags = [
    ArtRegion('05', Rect.fromLTWH(102, 968, 124, 96)),
    ArtRegion('05', Rect.fromLTWH(102, 1173, 124, 96)),
    ArtRegion('05', Rect.fromLTWH(102, 1378, 124, 96)),
    ArtRegion('05', Rect.fromLTWH(102, 1583, 124, 96)),
    ArtRegion('05', Rect.fromLTWH(102, 1788, 124, 96)),
    ArtRegion('05', Rect.fromLTWH(102, 1993, 124, 96)),
  ];
  static const reasonIcons = [
    ArtRegion('09', Rect.fromLTWH(96, 785, 140, 125)),
    ArtRegion('09', Rect.fromLTWH(96, 1003, 140, 125)),
    ArtRegion('09', Rect.fromLTWH(96, 1221, 140, 125)),
    ArtRegion('09', Rect.fromLTWH(96, 1439, 140, 125)),
    ArtRegion('09', Rect.fromLTWH(96, 1657, 140, 125)),
    ArtRegion('09', Rect.fromLTWH(96, 1875, 140, 125)),
    ArtRegion('09', Rect.fromLTWH(96, 2093, 140, 125)),
  ];
  static const benefitIcons = [
    ArtRegion('16', Rect.fromLTWH(102, 813, 130, 125)),
    ArtRegion('16', Rect.fromLTWH(102, 1106, 130, 125)),
    ArtRegion('16', Rect.fromLTWH(102, 1334, 130, 125)),
  ];
}

class ReferenceArt extends StatefulWidget {
  const ReferenceArt(
    this.region, {
    required this.width,
    required this.height,
    super.key,
  });
  final ArtRegion region;
  final double width;
  final double height;
  static AssetImage _provider(String file) => AssetImage(
    'assets/reference_art/${file.contains('-') ? file : 'onboarding-$file'}.png',
  );
  // Use Flutter's bounded image cache. A widget owns its ImageInfo while mounted;
  // visiting more source flows must not keep every decoded screenshot forever.
  static Future<void> _load(String file) {
    final done = Completer<void>();
    final stream = _provider(file).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, synchronous) {
        info.dispose();
        stream.removeListener(listener);
        if (!done.isCompleted) done.complete();
      },
      onError: (error, stack) {
        stream.removeListener(listener);
        if (!done.isCompleted) done.completeError(error, stack);
      },
    );
    stream.addListener(listener);
    return done.future;
  }

  static Future<void> preload() async {
    await Future.wait(
      [
        '02',
        '03',
        '04',
        '05',
        '07',
        '09',
        '15',
        '16',
        '19',
        '20',
        'login-03',
        'login-07',
        'login-17',
      ].map(_load),
    );
  }

  static Future<void> preloadFiles(Iterable<String> files) async {
    await Future.wait(files.map(_load));
  }

  @override
  State<ReferenceArt> createState() => _ReferenceArtState();
}

class _ReferenceArtState extends State<ReferenceArt> {
  ImageStream? _stream;
  ImageInfo? _info;
  late final _listener = ImageStreamListener(
    _receive,
    onError: (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'reference illustration',
        ),
      );
    },
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(ReferenceArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.region.file != widget.region.file) _resolve();
  }

  void _resolve() {
    final next = ReferenceArt._provider(widget.region.file)
        .resolve(createLocalImageConfiguration(context));
    if (next.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _replace(null);
    _stream = next;
    next.addListener(_listener);
  }

  void _receive(ImageInfo info, bool synchronous) {
    if (!mounted) {
      info.dispose();
      return;
    }
    setState(() => _replace(info));
  }

  void _replace(ImageInfo? info) {
    final old = _info;
    _info = info;
    // Match Flutter Image's ownership: an old painter can still be referenced
    // until the current frame finishes.
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _replace(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: widget.width,
      height: widget.height,
      child: _info != null
          ? CustomPaint(
              painter: _ArtPainter(_info!.image, widget.region.source),
            )
          : const SizedBox.shrink(),
    ),
  );
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.image, this.source);
  final ui.Image image;
  final Rect source;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawImageRect(
    image,
    source,
    Offset.zero & size,
    Paint()..filterQuality = FilterQuality.medium,
  );
  @override
  bool shouldRepaint(_ArtPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.source != source;
}
