import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appwrite/appwrite.dart';
import 'package:cocenglish/core/api/api_contracts.dart' as wire;
import 'package:cocenglish/core/api/client/access_token.dart';
import 'package:cocenglish/core/api/client/api_client.dart';
import 'package:cocenglish/core/api/client/api_operation.dart';
import 'package:cocenglish/core/api/client/api_transport.dart';
import 'package:cocenglish/core/api/client/service_apis.dart';
import 'package:cocenglish/core/cache/lesson_journal.dart';
import 'package:cocenglish/core/cache/lesson_journal_platform.dart';
import 'package:cocenglish/core/config/app_config.dart';
import 'package:cocenglish/core/config/local_tls.dart';
import 'package:cocenglish/features/learning/data/api_learning_repository.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

const _email = String.fromEnvironment('LOCAL_TEST_EMAIL');
const _password = String.fromEnvironment('LOCAL_TEST_PASSWORD');
const _courseId = 'vi_en';
const _signalName = 'local-offline-signal.json';

final class _Runtime {
  const _Runtime({
    required this.userId,
    required this.learning,
    required this.progress,
  });

  final String userId;
  final LearningApi learning;
  final ProgressApi progress;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real offline completion survives process restart and syncs once',
    (tester) async {
      final config = AppConfig.current;
      _validateConfiguration(config);
      configureLocalDevelopmentTls(config: config);

      final directory = await getApplicationDocumentsDirectory();
      final signal = File(
        '${directory.path}${Platform.pathSeparator}$_signalName',
      );
      debugPrint('LOCAL_OFFLINE_SIGNAL_PATH=${signal.path}');
      final initial = await _readSignal(signal);

      if (initial?['phase'] == 'staged') {
        await _resumeAfterRestart(config, signal, initial!);
        return;
      }
      expect(
        initial,
        isNull,
        reason: 'First process requires no private marker.',
      );
      await _stageWhileOffline(config, signal);
    },
  );
}

void _validateConfiguration(AppConfig config) {
  final expected = <ApiService, String>{
    ApiService.learning: 'https://10.0.2.2:4101',
    ApiService.progress: 'https://10.0.2.2:4102',
    ApiService.ai: 'https://10.0.2.2:4103',
  };
  if (!config.isApi ||
      config.appwriteEndpoint != 'https://10.0.2.2:8443/v1' ||
      config.appwriteProjectId != 'cocenglish-local' ||
      _email.isEmpty ||
      !_email.endsWith('@cocenglish.local') ||
      _password.length < 12 ||
      expected.entries.any(
        (entry) => config.serviceUrls[entry.key] != entry.value,
      )) {
    throw StateError('LOCAL_OFFLINE_CONFIGURATION_INVALID');
  }
}

Future<_Runtime> _authenticate(AppConfig config) async {
  final account = Account(
    Client()
        .setEndpoint(config.appwriteEndpoint)
        .setProject(config.appwriteProjectId),
  );
  try {
    final existing = await account.get();
    if (existing.email != _email)
      throw StateError('LOCAL_OFFLINE_ACCOUNT_MISMATCH');
  } on AppwriteException catch (error) {
    if (error.code != 401) rethrow;
    await account.createEmailPasswordSession(
      email: _email,
      password: _password,
    );
  }
  final user = await account.get();
  final tokens = CachingTokenProvider(
    () async => (await account.createJWT()).jwt,
  );
  final client = ApiClient(
    transport: ApiTransport.platformDefault(),
    tokens: tokens,
    timeout: const Duration(seconds: 3),
    maxRetries: 0,
    baseUrls: {
      for (final service in ApiService.values)
        service: config.baseUrl(service)!,
    },
  );
  return _Runtime(
    userId: user.$id,
    learning: LearningApi(client),
    progress: ProgressApi(client),
  );
}

Future<void> _stageWhileOffline(AppConfig config, File signal) async {
  final runtime = await _authenticate(config);
  final path = await runtime.learning.getPath(_courseId, limit: 100);
  final completed = path.enrollment.completedLessonIds.toSet();
  final node = path.nodes.firstWhere(
    (candidate) =>
        <String>{'available', 'current'}.contains(candidate.state) &&
        candidate.lessonIds.any(
          (String lessonId) => !completed.contains(lessonId),
        ),
    orElse: () => throw StateError('LOCAL_OFFLINE_NO_UNCOMPLETED_LESSON'),
  );
  final namespace =
      'qa.local.offline.${runtime.userId}.${DateTime.now().microsecondsSinceEpoch}';
  final journal = createDurableLessonJournal(namespace: namespace);
  final repository = ApiLearningRepository(
    learning: runtime.learning,
    progress: runtime.progress,
    journal: journal,
    courseId: _courseId,
    rewardPollDelay: const Duration(milliseconds: 250),
  );
  final before = await runtime.progress.getRewards();
  final exercises = await repository.loadLesson(node.nodeId);
  expect(exercises, isNotEmpty);
  await _writeSignal(signal, {
    'phase': 'ready-for-offline',
    'namespace': namespace,
    'exerciseCount': exercises.length,
  });
  await _waitForPhase(signal, 'network-offline');

  var correct = 0;
  for (final exercise in exercises) {
    if (await repository.grade(exercise, _correctAnswer(exercise))) correct++;
  }
  expect(
    correct,
    exercises.length,
    reason: 'Authored local grading must accept every answer.',
  );
  final receipt = await repository.complete(
    nodeId: node.nodeId,
    originalCorrect: correct,
    originalTotal: exercises.length,
    elapsed: const Duration(minutes: 2),
    guest: false,
    placement: false,
  );
  expect(receipt.id, startsWith('offline-'));
  expect(receipt.xp, 0, reason: 'Offline client must not award XP.');
  final pending = await journal.pendingCompletions();
  expect(pending, hasLength(1));
  await _writeSignal(signal, {
    'phase': 'staged',
    'namespace': namespace,
    'operationId': pending.single['operationId'],
    'beforeStudyXp': before.studyXp,
    'beforeRevision': before.revision,
  });

  await Future<void>.delayed(const Duration(days: 1)).timeout(
    const Duration(seconds: 90),
    onTimeout: () => throw TimeoutException('PROCESS_FORCE_STOP_TIMEOUT'),
  );
}

Future<void> _resumeAfterRestart(
  AppConfig config,
  File signal,
  Map<String, Object?> staged,
) async {
  final namespace = staged['namespace'];
  final operationId = staged['operationId'];
  final beforeStudyXp = staged['beforeStudyXp'];
  final beforeRevision = staged['beforeRevision'];
  if (namespace is! String ||
      !namespace.startsWith('qa.local.offline.') ||
      operationId is! String ||
      operationId.isEmpty ||
      beforeStudyXp is! int ||
      beforeRevision is! int) {
    throw StateError('LOCAL_OFFLINE_STAGED_MARKER_INVALID');
  }

  final runtime = await _authenticate(config);
  final journal = createDurableLessonJournal(namespace: namespace);
  if (!namespace.startsWith('qa.local.offline.${runtime.userId}.')) {
    throw StateError('LOCAL_OFFLINE_ACCOUNT_MISMATCH');
  }
  try {
    final pending = await journal.pendingCompletions();
    expect(
      pending,
      hasLength(1),
      reason: 'Queued operation must survive process death.',
    );
    expect(pending.single['operationId'], operationId);
    final original = Map<String, Object?>.from(pending.single);
    final repository = ApiLearningRepository(
      learning: runtime.learning,
      progress: runtime.progress,
      journal: journal,
      courseId: _courseId,
      rewardPollDelay: const Duration(milliseconds: 250),
    );
    await _writeSignal(signal, {
      'phase': 'ready-for-online',
      'queuedOperationPersisted': true,
    });

    expect(await repository.syncPending(), 1);
    expect(await journal.pendingCompletions(), isEmpty);
    final credited = await _waitForReward(
      runtime.progress,
      minimumStudyXp: beforeStudyXp + 1,
      minimumRevision: beforeRevision + 1,
    );

    await journal.enqueueCompletion(original);
    expect(
      await repository.syncPending(),
      1,
      reason: 'Lost local ack must replay safely.',
    );
    expect(await repository.syncPending(), 0);
    expect(await journal.pendingCompletions(), isEmpty);
    await Future<void>.delayed(const Duration(seconds: 2));
    final replayed = await runtime.progress.getRewards();
    expect(
      replayed.studyXp,
      credited.studyXp,
      reason: 'Replay must not award XP twice.',
    );
    expect(
      replayed.revision,
      credited.revision,
      reason: 'Replay must not add a ledger revision.',
    );

    await _writeSignal(signal, {
      'phase': 'passed',
      'queuedOperationPersisted': true,
      'queueEmpty': true,
      'rewardCreditedOnce': true,
      'studyXpDelta': credited.studyXp - beforeStudyXp,
    });
  } finally {
    if (journal is ClosableLessonJournal) await journal.close();
  }
}

Future<wire.Rewards> _waitForReward(
  ProgressApi progress, {
  required int minimumStudyXp,
  required int minimumRevision,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(deadline)) {
    final rewards = await progress.getRewards();
    if (rewards.studyXp >= minimumStudyXp &&
        rewards.revision >= minimumRevision) {
      return rewards;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  throw TimeoutException('REWARD_SETTLEMENT_TIMEOUT');
}

LessonAnswer _correctAnswer(Exercise exercise) => switch (exercise.kind) {
  ExerciseKind.choice ||
  ExerciseKind.imageChoice ||
  ExerciseKind.listenChoice => LessonAnswer(
    selectedId: exercise.correctIds.single,
  ),
  ExerciseKind.wordBank ||
  ExerciseKind.sentenceOrder => LessonAnswer(tokenIds: exercise.correctIds),
  ExerciseKind.matchPairs => LessonAnswer(matchedPairs: exercise.pairs),
  ExerciseKind.textTranslation ||
  ExerciseKind.fillBlank ||
  ExerciseKind.dictation ||
  ExerciseKind.speakRepeat ||
  ExerciseKind.dialogueTurn ||
  ExerciseKind.storyQuestion => LessonAnswer(text: exercise.correctText),
};

Future<Map<String, Object?>?> _readSignal(File file) async {
  try {
    if (!await file.exists()) return null;
    return Map<String, Object?>.from(
      jsonDecode(await file.readAsString()) as Map,
    );
  } on FileSystemException {
    return null;
  } on FormatException {
    return null;
  }
}

Future<void> _writeSignal(File file, Map<String, Object?> value) async {
  final temporary = File('${file.path}.tmp');
  await temporary.writeAsString('${jsonEncode(value)}\n', flush: true);
  await temporary.rename(file.path);
}

Future<void> _waitForPhase(File file, String expected) async {
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(deadline)) {
    if ((await _readSignal(file))?['phase'] == expected) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  throw TimeoutException('SIGNAL_PHASE_TIMEOUT:$expected');
}
