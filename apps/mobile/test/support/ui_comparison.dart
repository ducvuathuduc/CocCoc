import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

class UiComparison {
  UiComparison({this.flow = 'onboarding'});
  final String flow;
  final metrics = <Map<String, Object>>[];

  Future<void> compare(int screen, ui.Image render) async {
    final path =
        '../../docs/design/references/$flow/${screen.toString().padLeft(2, '0')}.png';
    final codec = await ui.instantiateImageCodec(
      await File(path).readAsBytes(),
    );
    final reference = (await codec.getNextFrame()).image;
    codec.dispose();
    if (render.width != reference.width || render.height != reference.height) {
      throw StateError('Reference dimensions differ');
    }
    final a = (await reference.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer
        .asUint8List();
    final b = (await render.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer
        .asUint8List();
    var total = 0;
    var foreground = 0;
    var totalError = 0;
    var foregroundError = 0;
    var changed = 0;
    for (
      var y = (59 * render.width / 390).round();
      y < render.height - (34 * render.width / 390).round();
      y++
    ) {
      for (var x = 0; x < render.width; x++) {
        final p = (y * render.width + x) * 4;
        var error = 0;
        var maximum = 0;
        var visible = false;
        for (var channel = 0; channel < 3; channel++) {
          final delta = (a[p + channel] - b[p + channel]).abs();
          error += delta;
          maximum = math.max(maximum, delta);
          visible = visible || a[p + channel] < 240 || b[p + channel] < 240;
        }
        total++;
        totalError += error;
        if (visible) {
          foreground++;
          foregroundError += error;
        }
        if (maximum > 12) changed++;
      }
    }
    metrics.add({
      'screen': screen,
      'frame': [render.width, render.height],
      'bodyMaeRgb': double.parse((totalError / (total * 3)).toStringAsFixed(3)),
      'foregroundMaeRgb': double.parse(
        (foregroundError / (foreground * 3)).toStringAsFixed(3),
      ),
      'pixelsBeyondTolerance': changed,
      'comparedPixels': total,
      'foregroundPixels': foreground,
    });
    reference.dispose();
  }

  Future<void> write() => File('../../docs/design/qa/$flow/metrics.json')
      .writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'frame': 'Per-screen dimensions below; 1179 or 1180 × 2556',
          'logicalWidth': 390,
          'excludeSystemInsets': [59, 34],
          'colorTolerance': 12,
          'foregroundDefinition': 'Either image has any RGB channel below 240',
          'note': 'Diagnostics, not a pixel-perfect score. White space can inflate whole-body similarity. Font/renderer differences remain.',
          'screens': metrics,
        }),
      );
}
