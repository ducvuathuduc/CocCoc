import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/progress/data/progress_snapshot.dart';
import 'package:cocenglish/features/shell/application/app_shell_providers.dart';
import 'package:cocenglish/features/shell/data/api_app_shell_repository.dart';
import 'package:cocenglish/features/shell/data/app_shell_repository.dart';
import 'package:cocenglish/features/shell/domain/app_shell_models.dart';
import 'package:cocenglish/features/shell/presentation/app_stats_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'features/api_snapshot_repositories_test.dart' as fixtures;
import 'support/app_fonts.dart';
import 'support/fake_api_transport.dart';
import 'support/settle_images.dart';

void main() {
  setUpAll(loadAppFonts);
  for (final dark in [false, true]) {
    for (final width in [320.0, 430.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'identical shell pixels dark=$dark width=$width text=$scale',
          (tester) async {
            tester.view.physicalSize = Size(width, 440);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            const state = AppShellSnapshot(
              score: 12,
              streak: 4,
              gems: 420,
              energy: 18,
              unlimited: false,
              streakActive: true,
            );
            final source = ProgressSnapshotSource(
              ApiEndpoints(fakeClient(FakeApiTransport())),
            );
            source.cache.put(
              ProgressSnapshot.fromJson({
                'profile': fixtures.profile(),
                'rewards': fixtures.rewards(),
                'energy': fixtures.energy(),
                'league': fixtures.league(),
                'leagueResult': fixtures.leagueResult(),
                'quests': fixtures.page([]),
              }),
            );
            addTearDown(source.cache.dispose);

            Future<Uint8List> render(List<AppStat> stats) async {
              final boundaryKey = GlobalKey();
              await tester.pumpWidget(
                ProviderScope(
                  key: UniqueKey(),
                  overrides: [appStatsProvider.overrideWithValue(stats)],
                  child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: referenceTheme(
                      brightness: dark ? Brightness.dark : Brightness.light,
                    ),
                    home: MediaQuery(
                      data: MediaQueryData(
                        size: Size(width, 440),
                        textScaler: TextScaler.linear(scale),
                        disableAnimations: true,
                      ),
                      child: RepaintBoundary(
                        key: boundaryKey,
                        child: Scaffold(body: AppStatsBar(onSelected: (_) {})),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              await settleImages(tester);
              expect(tester.takeException(), isNull);
              final boundary =
                  boundaryKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              return (await tester.runAsync(() async {
                final image = await boundary.toImage();
                final data = await image.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                );
                image.dispose();
                return data!.buffer.asUint8List();
              }))!;
            }

            final preview = await render(
              const MockAppShellRepository().stats(state),
            );
            final api = await render(
              ApiAppShellRepository(source).stats(state),
            );
            expect(
              api,
              orderedEquals(preview),
              reason: 'same state must retain approved rendering',
            );
          },
        );
      }
    }
  }
}
