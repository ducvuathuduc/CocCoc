import 'dart:convert';
import 'dart:io';

import 'package:cocenglish/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

// The rule these tests hold: a build that never said where its lessons come from must not boot the
// bundled fixtures and present them as dashboard content. `flutter test` is deliberately the
// undeclared case, so the guard lives in `main()` rather than in the widget tree tests pump.
final Directory _repoRoot = Directory.current.parent.parent;

String _repoFile(String repoRelativePath) =>
    File('${_repoRoot.path}/$repoRelativePath').readAsStringSync();

void main() {
  test('an undeclared build refuses to start on fixtures', () {
    final undeclared = AppConfig(declaredDataSource: false);
    final problem = undeclared.buildProblem;

    expect(problem, isNotNull);
    expect(problem, contains('DATA_SOURCE'));
    expect(problem, contains('config/real.public.json'));
  });

  test('the guard reads the compiled defines', () {
    // No `--dart-define` reaches a plain `flutter test`, so `AppConfig.current` is exactly the
    // build CI used to ship: `flutter build apk` with nothing declaring the source.
    expect(AppConfig.current.declaredDataSource, isFalse);
    expect(AppConfig.current.buildProblem, isNotNull);
  });

  test('a declared source clears the guard', () {
    const api = AppConfig(dataSource: DataSource.api, declaredDataSource: true);
    const fixtures = AppConfig(
      dataSource: DataSource.mock,
      declaredDataSource: true,
    );

    expect(api.buildProblem, isNull);
    expect(fixtures.buildProblem, isNull);
  });

  test('every build profile declares the api source', () {
    for (final profile in const [
      'apps/mobile/config/real.public.json',
      'apps/mobile/config/local.android.public.json',
    ]) {
      final decoded = jsonDecode(_repoFile(profile)) as Map<String, dynamic>;
      expect(decoded['DATA_SOURCE'], 'api', reason: profile);
    }
  });

  test('CI builds the app from a declared profile', () {
    final workflow = _repoFile('.github/workflows/mobile.yml');
    final buildLines = workflow
        .split('\n')
        .where((line) => line.contains('run: flutter build '))
        .toList();

    expect(buildLines, isNotEmpty);
    for (final line in buildLines) {
      expect(
        line,
        contains('--dart-define-from-file=config/real.public.json'),
        reason: line.trim(),
      );
    }
  });

  test('the fixture preview declares itself as a fixture', () {
    // The browser preview is a local fixture preview by design, but that has to be a choice the
    // build makes, not the silence of a missing define.
    expect(
      _repoFile('tools/scripts/mobile-web-build.mjs'),
      contains('--dart-define=DATA_SOURCE=mock'),
    );
  });
}
