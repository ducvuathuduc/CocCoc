import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cocenglish/core/api/api_contracts.dart' as wire;
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/data/learning_repository.dart';
import 'package:cocenglish/features/learning/data/lesson_audio_catalog.g.dart';
import 'package:cocenglish/features/learning/data/lesson_audio_store.dart';
import 'package:cocenglish/features/learning/data/lesson_wire_mapper.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/learning/presentation/lesson_screen.dart';
import 'package:cocenglish/features/learning/services/lesson_audio_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String hashOf(List<int> bytes) => sha256.convert(bytes).toString();

class MemoryAudioCache implements LessonAudioCache {
  final Map<String, Uint8List> files = {};

  @override
  Future<CachedClip?> read(String sha256) async {
    final bytes = files[sha256];
    return bytes == null ? null : CachedClip('/cache/$sha256.aac', bytes);
  }

  @override
  Future<String?> write(String sha256, Uint8List bytes) async {
    files[sha256] = bytes;
    return '/cache/$sha256.aac';
  }
}

/// Records what the lesson asked the speaker to play.
class RecordingOutput implements LessonSoundOutput {
  final voice = <String>[];
  final effects = <String>[];

  @override
  Future<void> playVoice(LessonAudioSource source) async => voice.add(
    switch (source) {
      BundledLessonAudio(:final path) => path,
      CachedLessonAudio(:final path) => path,
    },
  );

  @override
  Future<void> playEffect(String asset) async => effects.add(asset);

  @override
  Future<void> stopVoice() async {}

  @override
  void dispose() {}
}

void main() {
  final clipBytes = Uint8List.fromList(utf8.encode('fake aac clip'));
  final clipHash = hashOf(clipBytes);

  group('LessonAudioStore', () {
    LessonAudioStore store({
      Uint8List? served,
      MemoryAudioCache? cache,
      List<Uri>? requests,
      Map<String, String>? bundled,
    }) => LessonAudioStore(
      endpoint: 'https://sgp.cloud.appwrite.io/v1',
      projectId: 'p1',
      cache: cache ?? MemoryAudioCache(),
      bundled: bundled ?? {'a.u1.s1.n': clipHash},
      fetcher: (url, max) async {
        requests?.add(url);
        return served;
      },
    );

    test('uses the shipped clip when its hash matches (or mock has none)',
        () async {
      final s = store();
      expect(
        await s.resolve(LessonAudio('a.u1.s1.n', clipHash)),
        const BundledLessonAudio('lesson_audio/a.u1.s1.n.aac'),
      );
      expect(
        await s.resolve(const LessonAudio('a.u1.s1.n')),
        const BundledLessonAudio('lesson_audio/a.u1.s1.n.aac'),
      );
      expect(await s.resolve(const LessonAudio('a.u9.s9.n')), isNull);
    });

    test('downloads a published clip by fileId, verifies and caches it',
        () async {
      final requests = <Uri>[];
      final cache = MemoryAudioCache();
      final s = store(served: clipBytes, cache: cache, requests: requests);
      final clip = LessonAudio('a.u2.s3.s', clipHash);
      expect(
        await s.resolve(clip),
        CachedLessonAudio('/cache/$clipHash.aac'),
      );
      expect(
        requests.single.toString(),
        'https://sgp.cloud.appwrite.io/v1/storage/buckets/learning-assets/'
        'files/a.u2.s3.s/view?project=p1',
      );
      expect(cache.files[clipHash], clipBytes);
      // Second time: served from the cache, no network.
      expect(await s.resolve(clip), CachedLessonAudio('/cache/$clipHash.aac'));
      expect(requests, hasLength(1));
    });

    test('rejects bytes whose hash differs; falls back to the shipped clip',
        () async {
      final tampered = Uint8List.fromList(utf8.encode('other bytes'));
      final cache = MemoryAudioCache();
      final s = store(served: tampered, cache: cache);
      // Newer published hash than the shipped clip: download is bad, so the
      // shipped clip with the same fileId plays.
      expect(
        await s.resolve(LessonAudio('a.u1.s1.n', hashOf(utf8.encode('v2')))),
        const BundledLessonAudio('lesson_audio/a.u1.s1.n.aac'),
      );
      expect(await s.resolve(LessonAudio('a.u5.d1.n', clipHash)), isNull);
      expect(cache.files, isEmpty);
    });

    test('word slugs match the content generator', () {
      expect(wordAudioSlug('Hello'), 'hello');
      expect(wordAudioSlug('I’m'), 'i_m');
      expect(wordAudioSlug("o'clock"), 'o_clock');
      expect(wordAudioSlug('get up'), 'get_up');
      expect(store().bundledWord('I'), isNull);
      expect(
        store(bundled: {'a.w.i.n': clipHash}).bundledWord('I'),
        const LessonAudio('a.w.i.n'),
      );
    });

    test('every shipped mock clip exists with its catalogued hash', () {
      expect(bundledLessonAudio, isNotEmpty);
      for (final entry in bundledLessonAudio.entries) {
        final file = File('assets/lesson_audio/${entry.key}.aac');
        expect(file.existsSync(), isTrue, reason: entry.key);
        expect(hashOf(file.readAsBytesSync()), entry.value, reason: entry.key);
      }
      for (final sfx in LessonSfx.values) {
        expect(File('assets/${sfx.asset}').existsSync(), isTrue);
      }
    });
  });

  group('LessonWireMapper audio', () {
    final bundle = wire.LessonBundle.fromJson(
      jsonDecode(
            File(
              '../../content/vi_en/dist/v2/bundles/u1n1l3.json',
            ).readAsStringSync(),
          )
          as Map<String, Object?>,
    );
    final mapper = LessonWireMapper(bundle.exercises, assets: bundle.assets);
    final hashes = {for (final a in bundle.assets) a.fileId: a.sha256};

    test('listen items carry hash-pinned normal + slow prompt clips', () {
      final listen = mapper.toDomain().firstWhere(
        (e) => e.kind == ExerciseKind.listenChoice,
      );
      final wireJson = mapper.wireJson(listen.id)!;
      final id =
          (wireJson['prompt']! as Map<String, Object?>)['audioAssetId']!
              as String;
      expect(listen.audio, LessonAudio(id, hashes[id]));
      final slow = '${id.substring(0, id.length - 2)}.s';
      expect(listen.slowAudio, LessonAudio(slow, hashes[slow]));
      // Real Azure clips, not placeholder hashes.
      final asset = bundle.assets.firstWhere((a) => a.fileId == id);
      expect(asset.provider.value, 'azure-tts');
      expect(asset.voice.value, startsWith('en-US-'));
    });

    test('tile words resolve to the bundle word clips', () {
      final bank = mapper.toDomain().firstWhere(
        (e) => e.kind == ExerciseKind.wordBank,
      );
      final english = bank.tokens.firstWhere(
        (t) => bank.wordAudio.containsKey(wordAudioSlug(t.text)),
      );
      final clip = bank.wordAudio[wordAudioSlug(english.text)]!;
      expect(clip.sha256, hashes[clip.fileId]);
      expect(clip.fileId, startsWith('a.w.'));
    });
  });

  group('lesson screen audio', () {
    Future<(ProviderContainer, RecordingOutput)> pumpLesson(
      WidgetTester tester,
      List<Exercise> exercises,
    ) async {
      final output = RecordingOutput();
      final container = ProviderContainer(
        overrides: [
          learningRepositoryProvider.overrideWithValue(
            MockLearningRepository(delay: Duration.zero),
          ),
          lessonSoundOutputProvider.overrideWithValue(output),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(lessonControllerProvider.notifier)
          .start(exercises: exercises);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: referenceTheme(),
            home: const LessonScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (container, output);
    }

    Exercise byId(String id) => [
      ...mockEnglishExercises,
      ...mockPracticeExercises,
    ].firstWhere((e) => e.id == id);

    testWidgets('listen prompt autoplays; speaker alternates normal/slow', (
      tester,
    ) async {
      final (_, output) = await pumpLesson(tester, [
        byId('english-06-listen'),
      ]);
      expect(output.voice, ['lesson_audio/m.a_girl.n.aac']);
      await tester.tap(find.byTooltip('Listen'));
      await tester.pump();
      await tester.tap(find.byTooltip('Listen'));
      await tester.pump();
      expect(output.voice, [
        'lesson_audio/m.a_girl.n.aac',
        'lesson_audio/m.a_girl.s.aac',
        'lesson_audio/m.a_girl.n.aac',
      ]);
    });

    testWidgets('dictation autoplays its sentence', (tester) async {
      final (_, output) = await pumpLesson(tester, [
        byId('english-practice-dictation'),
      ]);
      expect(output.voice, ['lesson_audio/m.i_am_here.n.aac']);
    });

    testWidgets('tapping word tiles speaks each word', (tester) async {
      final (_, output) = await pumpLesson(tester, [byId('english-03-bank')]);
      expect(output.voice, isEmpty);
      await tester.tap(find.text('I'));
      await tester.pump();
      await tester.tap(find.text('woman'));
      await tester.pump();
      expect(output.voice, [
        'lesson_audio/a.w.i.n.aac',
        'lesson_audio/a.w.woman.n.aac',
      ]);
    });

    testWidgets('correct and incorrect answers play their sound effects', (
      tester,
    ) async {
      final (container, output) = await pumpLesson(tester, [
        byId('english-02-choice'),
        byId('english-02-choice'),
      ]);
      final vm = container.read(lessonControllerProvider.notifier);
      await tester.tap(find.text('woman'));
      await tester.pump();
      expect(output.voice.last, 'lesson_audio/a.w.woman.n.aac');
      await tester.runAsync(vm.check);
      await tester.pumpAndSettle();
      expect(output.effects, [LessonSfx.correct.asset]);
      vm.next();
      await tester.pumpAndSettle();
      vm.select('boy');
      await tester.runAsync(vm.check);
      await tester.pumpAndSettle();
      expect(output.effects.sublist(1, 2), [LessonSfx.incorrect.asset]);
      // The heart-loss pop follows the "incorrect" sound. check() ran under
      // runAsync, so the 180 ms delay is a real timer.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      if (container.read(lessonControllerProvider).hearts < 5) {
        expect(output.effects.last, LessonSfx.heartLoss.asset);
      }
    });

    testWidgets('sound effects follow the Sound effects setting', (
      tester,
    ) async {
      final output = RecordingOutput();
      final service = LessonAudioService(
        store: LessonAudioStore(endpoint: 'e', projectId: 'p'),
        output: output,
        effectsEnabled: () => false,
      );
      await service.effect(LessonSfx.correct);
      expect(output.effects, isEmpty);
      expect(await service.play(const LessonAudio('m.hello.n')), isTrue);
      expect(output.voice, ['lesson_audio/m.hello.n.aac']);
    });
  });
}
