import 'dart:async';

import 'package:cocenglish/core/design/duo_motion.dart';
import 'package:cocenglish/features/progress/data/league_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_fonts.dart';

/// Global test setup. Idle mascots loop forever in the app; in widget tests
/// they hold their first frame so `pumpAndSettle` stays deterministic. Tests that
/// exercise looping itself reset [DuoMotion.debugSingleCycleLoops]. The
/// mock league is pinned to its 8-learner reference cohort the same way.
///
/// Every test file also gets the real bundled fonts (DuolingoSans, Feather,
/// Material icons) so goldens always compare real glyphs, never Ahem boxes.
/// Goldens are canonical on Linux with the Flutter version pinned in
/// tools/toolchain.json (the CI platform); regenerate them there.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  DuoMotion.debugSingleCycleLoops = true;
  debugPinReferenceLeague = true;
  await loadAppFonts();
  await testMain();
}
