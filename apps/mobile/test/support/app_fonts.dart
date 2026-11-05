import 'dart:io';

import 'package:flutter/services.dart';
import 'package:cocenglish/core/design/reference_art.dart';

/// Use Flutter's open licensed test font; proprietary app fonts stay unbundled.
Future<ByteData> loadTestFont({bool bold = false}) async {
  var directory = File(Platform.resolvedExecutable).parent;
  while (true) {
    final font = File(
      '${directory.path}/bin/cache/artifacts/material_fonts/Roboto-${bold ? 'Bold' : 'Regular'}.ttf',
    );
    if (await font.exists()) {
      return ByteData.sublistView(await font.readAsBytes());
    }
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  throw StateError('Pinned Flutter material test fonts not found');
}

/// Keep golden font metrics stable without adding fonts to the app bundle.
Future<void> loadAppFonts() async {
  await ReferenceArt.preload();
  await (FontLoader('sans-serif')
        ..addFont(loadTestFont())
        ..addFont(loadTestFont(bold: true)))
      .load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}
