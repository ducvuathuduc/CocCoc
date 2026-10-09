import 'package:cocenglish/core/design/character_motion.dart';
import 'package:flutter/material.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

void main() {
  testWidgets(
    'character reacts, pauses on background, and disposes its runtime',
    (tester) async {
      final key = GlobalKey();
      Widget harness(
        CharacterReaction reaction, [
        LessonCharacter character = LessonCharacter.falstaff,
      ]) => MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: CharacterMotion(
              character: character,
              width: 144,
              height: 176,
              enabled: true,
              reaction: reaction,
              fallback: const SizedBox(key: ValueKey('loading')),
            ),
          ),
        ),
      );
      await tester.pumpWidget(harness(CharacterReaction.reset));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(rive.RiveWidget), findsOneWidget);
      var widget = tester.widget<rive.RiveWidget>(find.byType(rive.RiveWidget));
      expect(widget.controller.active, isTrue);
      if (const bool.fromEnvironment('CAPTURE_CAST')) {
        for (final character in LessonCharacter.values) {
          await tester.pumpWidget(harness(CharacterReaction.reset, character));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 250)),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(
            find.byType(rive.RiveWidget),
            findsOneWidget,
            reason: character.name,
          );
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final frame = await boundary.toImage(pixelRatio: 3);
            final data = (await frame.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            final file = File(
              '../../docs/design/qa/cast/${character.name}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data.buffer.asUint8List());
            frame.dispose();
          });
        }
        await tester.pumpWidget(harness(CharacterReaction.reset));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        widget = tester.widget<rive.RiveWidget>(find.byType(rive.RiveWidget));
      }
      for (final reaction in CharacterReaction.values) {
        await tester.pumpWidget(harness(reaction));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        if (const bool.fromEnvironment('CAPTURE_CHARACTER')) {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final frame = await boundary.toImage(pixelRatio: 3);
            final data = (await frame.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File('../../docs/design/qa/character-${reaction.name}.png')
                .writeAsBytes(data.buffer.asUint8List());
            frame.dispose();
          });
        }
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(widget.controller.active, isFalse);
      expect(find.byKey(const ValueKey('loading')), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(widget.controller.active, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'original character files expose verified feedback state machines',
    (tester) async {
      await tester.runAsync(() async {
        await rive.RiveNative.init();
        for (final character in LessonCharacter.values) {
          final file = (await rive.File.asset(
            character.asset,
            riveFactory: rive.Factory.flutter,
          ))!;
          final controller = rive.RiveWidgetController(
            file,
            artboardSelector: rive.ArtboardSelector.byName('character'),
            stateMachineSelector: rive.StateMachineSelector.byName(
              'character_statemachine',
            ),
          );
          try {
            for (final reaction in CharacterReaction.values) {
              // Original exports predate Rive data binding.
              // ignore: deprecated_member_use
              final trigger = controller.stateMachine.trigger(reaction.input);
              expect(
                trigger,
                isNotNull,
                reason: '${character.name}/${reaction.input}',
              );
              trigger?.fire();
              controller.stateMachine.advanceAndApply(.016);
              trigger?.dispose();
            }
            // ignore: deprecated_member_use
            final dark = controller.stateMachine.boolean('darkmode_bool');
            expect(dark, isNotNull);
            dark?.dispose();
          } finally {
            controller.dispose();
            file.dispose();
          }
        }
      });
    },
  );
  testWidgets(
    'character reduced motion and hidden routes preserve the fallback',
    (tester) async {
      Widget harness(bool reduced, bool ticker) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: TickerMode(
            enabled: ticker,
            child: const CharacterMotion(
              character: LessonCharacter.falstaff,
              width: 99,
              height: 149,
              fallback: SizedBox(key: ValueKey('still')),
            ),
          ),
        ),
      );
      await tester.pumpWidget(harness(true, true));
      expect(find.byKey(const ValueKey('still')), findsOneWidget);
      expect(find.byType(rive.RiveWidget), findsNothing);
      await tester.pumpWidget(harness(false, false));
      expect(find.byKey(const ValueKey('still')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
