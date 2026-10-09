import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [arguments]) async {
    final flow = name.contains('motion')
        ? 'motion'
        : name.contains('login')
        ? 'login'
        : 'onboarding';
    final file = File('../../docs/design/qa/$flow/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return true;
  },
);
