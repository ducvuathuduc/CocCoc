import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/call/application/call_controller.dart';
import 'package:cocenglish/features/call/data/call_repository.dart';
import 'package:cocenglish/features/call/domain/call_models.dart';
import 'package:cocenglish/features/call/presentation/call_visuals.dart';
import 'package:cocenglish/features/call/presentation/call_widgets.dart';
import 'package:cocenglish/features/call/presentation/video_call_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _session = MockCallRepository.lily;
const _ring = Duration(seconds: 2);
const _page = Duration(milliseconds: 400);

void main() {
  setUpAll(() async {
    await (FontLoader('DuolingoSans')
          ..addFont(rootBundle.load('assets/fonts/DuolingoSans.ttf'))
          ..addFont(rootBundle.load('assets/fonts/DuolingoSans-Bold.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await ReferenceArt.preloadFiles(CallArt.files);
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpCall(
    WidgetTester tester, {
    bool reduced = false,
    VoidCallback? onExit,
    VoidCallback? onUpgrade,
  }) async {
    phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: referenceTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!,
          ),
          home: RepaintBoundary(
            key: const ValueKey('call-golden'),
            child: VideoCallScreen(onExit: onExit, onUpgrade: onUpgrade),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> golden(WidgetTester tester, String name) => expectLater(
    find.byKey(const ValueKey('call-golden')),
    matchesGoldenFile('goldens/ui_master/sprint_call_${name}_430.png'),
  );

  Future<void> toConnectedCaption(WidgetTester tester) async {
    await tester.pump(_ring);
    await tester.pump(_page);
    await tester.pump(_session.partnerLineDuration);
    await tester.pump(_page);
  }

  testWidgets('ringing: calling copy, pulse rings and hang-up', (tester) async {
    await pumpCall(tester);
    expect(find.text('Calling Lily...'), findsOneWidget);
    expect(find.byKey(const ValueKey('ringing-pulse')), findsOneWidget);
    expect(find.bySemanticsLabel('Hang up'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await golden(tester, 'ringing');
  });

  testWidgets('connects, shows caption, mic listens then commits reply', (
    tester,
  ) async {
    await pumpCall(tester);
    await toConnectedCaption(tester);
    expect(find.text('Calling Lily...'), findsNothing);
    expect(find.text('Good evening.'), findsOneWidget);
    await golden(tester, 'connected');

    await tester.tap(find.byKey(const ValueKey('call-mic')));
    await tester.pump();
    expect(find.byKey(const ValueKey('listening-waveform')), findsOneWidget);
    expect(find.text('Listening…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    await golden(tester, 'listening');

    await tester.pump(_session.listenDuration);
    await tester.pump(_page);
    expect(find.byKey(const ValueKey('listening-waveform')), findsNothing);
    // Lily answers on her own after her line duration.
    await tester.pump(_session.partnerLineDuration);
    await tester.pump(_page);
    expect(find.text('How are you?'), findsOneWidget);
  });

  testWidgets('mic is ignored while Lily is speaking', (tester) async {
    await pumpCall(tester);
    await tester.pump(_ring);
    await tester.pump(_page);
    await tester.tap(find.byKey(const ValueKey('call-mic')));
    await tester.pump();
    expect(find.byKey(const ValueKey('listening-waveform')), findsNothing);
  });

  testWidgets('hang up → XP → review → upsell → no thanks exits', (
    tester,
  ) async {
    var exited = 0;
    var upgraded = 0;
    await pumpCall(tester, onExit: () => exited++, onUpgrade: () => upgraded++);
    await toConnectedCaption(tester);
    // Speak a few turns so the review has a conversation to show.
    for (var turn = 0; turn < 2; turn++) {
      await tester.tap(find.byKey(const ValueKey('call-mic')));
      await tester.pump(_session.listenDuration);
      await tester.pump(_session.partnerLineDuration);
      await tester.pump(_page);
    }
    await tester.pump(_session.partnerLineDuration);
    await tester.pump(_page);
    await tester.tap(find.bySemanticsLabel('Hang up'));
    await tester.pump();
    await tester.pump(_page);
    expect(find.text('You earned 20 XP!'), findsOneWidget);
    await golden(tester, 'ended');

    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    await tester.pump(_page);
    expect(find.text('Review your conversation'), findsOneWidget);
    expect(find.text('Good evening.'), findsNWidgets(2));
    expect(find.text('Do you speak English?'), findsOneWidget);
    await golden(tester, 'review');

    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    await tester.pump(_page);
    expect(find.text('UPGRADE TO MAX'), findsOneWidget);
    await golden(tester, 'upsell');

    await tester.tap(find.text('UPGRADE TO MAX'));
    expect(upgraded, 1);
    await tester.tap(find.text('NO THANKS'));
    expect(exited, 1);
  });

  testWidgets('full script plays out and auto-ends; review lists every line', (
    tester,
  ) async {
    await pumpCall(tester);
    await tester.pump(_ring);
    for (var i = 0; i < _session.script.length; i++) {
      final line = _session.script[i];
      if (line.speaker == CallSpeaker.learner) {
        await tester.tap(find.byKey(const ValueKey('call-mic')));
        await tester.pump(_session.listenDuration);
      } else {
        await tester.pump(_session.partnerLineDuration);
      }
      await tester.pump(_page);
    }
    await tester.pump(_session.partnerLineDuration);
    await tester.pump(_page);
    expect(find.text('You earned 20 XP!'), findsOneWidget);
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    await tester.pump(_page);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(VideoCallScreen)),
    );
    expect(
      container.read(callControllerProvider).spoken.length,
      _session.script.length,
    );
  });

  testWidgets('reduced motion: whole flow settles with no animation loops', (
    tester,
  ) async {
    await pumpCall(tester, reduced: true, onExit: () {});
    await tester.pumpAndSettle();
    expect(find.text('Calling Lily...'), findsOneWidget);
    await tester.pump(_ring);
    await tester.pumpAndSettle();
    await tester.pump(_session.partnerLineDuration);
    await tester.pumpAndSettle();
    expect(find.text('Good evening.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('call-mic')));
    await tester.pumpAndSettle();
    await tester.pump(_session.listenDuration);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Hang up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('NO THANKS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hang-up press sinks the face onto its edge', (tester) async {
    await pumpCall(tester);
    final face = find.byKey(const ValueKey('hang-up-face'));
    final before = tester.getTopLeft(face).dy;
    final gesture = await tester.startGesture(tester.getCenter(face));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getTopLeft(face).dy, greaterThan(before));
    await gesture.up();
    await tester.pump(_page);
  });

  testWidgets('screen reads data from the repository provider', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [callRepositoryProvider.overrideWithValue(_FakeRepo())],
        child: const MaterialApp(home: VideoCallScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Ringing Zari'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('intro card golden and actions', (tester) async {
    phone(tester);
    var calls = 0;
    var later = 0;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: referenceTheme(),
        home: Scaffold(
          backgroundColor: ReferenceColors.surface,
          body: RepaintBoundary(
            key: const ValueKey('call-golden'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(29, 528, 29, 0),
              child: Align(
                alignment: Alignment.topCenter,
                child: VideoCallIntroCard(
                  copy: _session.copy,
                  onCall: () => calls++,
                  onLater: () => later++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await golden(tester, 'intro');
    await tester.tap(find.text('CALL FOR FREE +15 XP'));
    await tester.tap(find.text('DO THIS LATER'));
    expect((calls, later), (1, 1));
  });
}

class _FakeRepo implements CallRepository {
  @override
  Future<void> completeCall(String sessionId, int linesSpoken) async {}

  @override
  Future<CallSession> loadSession(String partnerId) async => CallSession(
    id: 'fake',
    partnerName: 'Zari',
    learnerInitial: 'T',
    xpReward: 5,
    script: const [CallLine(speaker: CallSpeaker.partner, text: 'Hi')],
    copy: CallCopy(
      introTitle: 'x',
      introCallLabel: 'x',
      introLaterLabel: 'x',
      callingLabel: 'Ringing Zari',
      earnedLabel: 'x',
      reviewTitle: 'x',
      continueLabel: 'x',
      upsellLead: 'x',
      upsellHighlight: 'x',
      upsellTail: 'x',
      upgradeLabel: 'x',
      noThanksLabel: 'x',
      phoneKicker: 'x',
      maxBadge: 'x',
      listeningLabel: 'x',
    ),
  );
}
