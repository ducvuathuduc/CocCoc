import 'dart:convert';

import 'package:cocenglish/core/api/api_contracts.dart' as wire;
import 'package:cocenglish/core/api/client/active_course.dart';
import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/core/api/client/api_exception.dart';
import 'package:cocenglish/core/cache/snapshot_cache.dart';
import 'package:cocenglish/features/call/data/api_call_repository.dart';
import 'package:cocenglish/features/learning/data/path_repository.dart';
import 'package:cocenglish/features/learning/domain/course_catalog.dart';
import 'package:cocenglish/features/notifications/data/api_notification_repository.dart';
import 'package:cocenglish/features/notifications/domain/notification_models.dart';
import 'package:cocenglish/features/practice/data/api_practice_repository.dart';
import 'package:cocenglish/features/progress/data/api_achievements_repository.dart';
import 'package:cocenglish/features/progress/data/league_repository.dart';
import 'package:cocenglish/features/progress/data/progress_snapshot.dart';
import 'package:cocenglish/features/progress/data/social_repository.dart';
import 'package:cocenglish/features/progress/domain/league_result.dart';
import 'package:cocenglish/features/quests/data/api_quests_repository.dart';
import 'package:cocenglish/features/quests/domain/quest_models.dart';
import 'package:cocenglish/features/results/data/api_results_repository.dart';
import 'package:cocenglish/features/results/domain/results_models.dart';
import 'package:cocenglish/features/roleplay/data/api_roleplay_repository.dart';
import 'package:cocenglish/features/shell/data/api_app_shell_repository.dart';
import 'package:cocenglish/features/shell/domain/app_shell_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_api_transport.dart';

const _iso = '2026-10-12T08:00:00.000Z';

Map<String, Object?> quest(
  String id,
  String period, {
  int target = 2,
  int metric = 0,
  bool claimed = false,
  int gems = 5,
}) => {
  'questId': id,
  'period': period,
  'periodKey': period == 'DAY'
      ? '2026-10-12'
      : period == 'MONTH'
      ? '2026-10'
      : '2026-W42',
  'target': target,
  'metricValue': metric,
  'claimed': claimed,
  'rewardGems': gems,
};

Map<String, Object?> page(List<Object?> items) => {
  'items': items,
  'nextCursor': null,
  'asOf': _iso,
};

Map<String, Object?> profile({List<String> achievements = const []}) => {
  'userId': 'me',
  'nickname': 'Thanh',
  'avatarId': null,
  'publicOptIn': true,
  'dailyGoal': 10,
  'learningZone': 'Asia/Ho_Chi_Minh',
  'pendingZone': null,
  'zoneEffectiveAt': null,
  'revision': 1,
  'achievementIds': achievements,
};

Map<String, Object?> rewards({int gems = 420, int streak = 4}) => {
  'completionId': null,
  'status': 'credited',
  'studyXp': 300,
  'leagueXp': 120,
  'gems': gems,
  'freezeSlots': 1,
  'currentStreak': streak,
  'awardXp': null,
  'revision': 3,
  'asOf': _iso,
};

Map<String, Object?> energy({String mode = 'LIMITED', int balance = 18}) => {
  'mode': mode,
  'balance': balance,
  'capacity': 25,
  'nextUnitAt': null,
  'fullAt': null,
  'revision': 2,
  'asOf': _iso,
};

Map<String, Object?> member(String id, String name, int xp, int rank) => {
  'userId': id,
  'nickname': name,
  'eligibleXp': xp,
  'rank': rank,
  'lastXpAt': null,
};

Map<String, Object?> league() => {
  'weekId': '2026-W42',
  'cohortId': 'c1',
  'tier': 1,
  'status': 'OPEN',
  'members': [
    member('a', 'Linh', 300, 1),
    member('b', 'Minh', 250, 2),
    member('me', 'Thanh', 120, 3),
    member('c', 'Lan', 90, 4),
  ],
  'asOf': _iso,
  'nextCursor': null,
};

Map<String, Object?> leagueResult({bool unseen = true}) => {
  'tier': 1,
  'stage': 'LEAGUE',
  'weeksParticipated': 3,
  'topThreeFinishes': 1,
  'diamondWeeks': 0,
  'lastResult': {
    'weekId': '2026-W41',
    'previousTier': 0,
    'tier': 1,
    'stage': 'LEAGUE',
    'rank': 2,
    'outcome': 'PROMOTED',
    'gemsAwarded': 30,
  },
  'unseen': unseen,
  'asOf': _iso,
};

Map<String, Object?> preferences({
  List<String> off = const [],
  int revision = 4,
}) => {
  'notificationsOff': off,
  'smartScheduling': true,
  'reminderMinute': 19 * 60 + 30,
  'soundEffects': true,
  'haptics': true,
  'motivationalMessages': true,
  'listeningExercises': true,
  'speakingExercises': true,
  'friendStreakInvites': true,
  'revision': revision,
  'asOf': _iso,
};

Map<String, Object?> conversation(
  String id,
  String scenario, {
  String status = 'COMPLETED',
  int stars = 2,
  int words = 10,
  String kind = 'ROLEPLAY',
}) => {
  'conversationId': id,
  'kind': kind,
  'courseId': 'vi_en',
  'scenarioId': scenario,
  'voiceSessionId': null,
  'status': status,
  'startedAt': _iso,
  'completedAt': status == 'COMPLETED' ? _iso : null,
  'turnCount': 6,
  'wordsUsed': words,
  'stars': stars,
  'xpAwarded': 10,
  'feedback': null,
  'expiresAt': _iso,
};

Map<String, Object?> receipt() => {
  'operationId': 'op',
  'status': 'accepted',
  'requestId': 'req',
};

void main() {
  late FakeApiTransport transport;
  late ApiEndpoints api;
  late ActiveCourse course;

  setUp(() {
    transport = FakeApiTransport();
    api = ApiEndpoints(fakeClient(transport));
    course = ActiveCourse(api, fixed: 'vi_en');
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  void progressRoutes({Map<String, Object?>? result, bool inLeague = true}) {
    transport
      ..json('GET /base/v1/me', profile())
      ..json('GET /base/v1/me/rewards', rewards())
      ..json('GET /v1/me/energy', energy())
      ..json('GET /base/v1/league/result', result ?? leagueResult())
      ..json(
        'GET /base/v1/quests',
        page([
          quest('daily_lessons', 'DAY', metric: 2),
          quest('friend_lessons10', 'WEEK', target: 10, metric: 4),
        ]),
      );
    if (inLeague) {
      transport.json('GET /base/v1/league', league());
    } else {
      transport.json(
        'GET /base/v1/league',
        errorEnvelope('NOT_FOUND'),
        status: 404,
      );
    }
  }

  group('SnapshotCache', () {
    test(
      'hydrates the persisted value, then replaces it with the fetch',
      () async {
        final store = MemorySnapshotStore()..values['k'] = jsonEncode({'n': 1});
        var changes = 0;
        final cache = SnapshotCache<int>(
          key: 'k',
          host: SnapshotHost(store: store, onChanged: () => changes++),
          decode: (j) => j['n']! as int,
          encode: (v) => {'n': v},
        );
        expect(cache.value, isNull);
        await cache.refresh(() async => 2);
        expect(cache.value, 2);
        expect(changes, 2, reason: 'hydrate + fetch');
        expect(jsonDecode(store.values['k']!), {'n': 2});
      },
    );

    test(
      'a failed refresh keeps the previous value and records the error',
      () async {
        final cache = SnapshotCache<int>(
          key: 'k',
          host: SnapshotHost.detached(),
          decode: (j) => j['n']! as int,
          encode: (v) => {'n': v},
        );
        await cache.refresh(() async => 5);
        await cache.refresh(() async => throw StateError('offline'));
        expect(cache.value, 5);
        expect(cache.error, isA<StateError>());
      },
    );

    test('single-flight and stale-while-revalidate after maxAge', () async {
      var now = DateTime(2026, 10, 12, 8);
      var calls = 0;
      final cache = SnapshotCache<int>(
        key: 'k',
        host: SnapshotHost.detached(),
        decode: (j) => j['n']! as int,
        encode: (v) => {'n': v},
        maxAge: const Duration(seconds: 30),
        clock: () => now,
      );
      Future<int> fetch() async => ++calls;
      cache
        ..ensureLoaded(fetch)
        ..ensureLoaded(fetch);
      await settle();
      await settle();
      expect(calls, 1);
      cache.ensureLoaded(fetch);
      await settle();
      expect(calls, 1, reason: 'fresh');
      now = now.add(const Duration(seconds: 31));
      cache.ensureLoaded(fetch);
      await settle();
      await settle();
      expect(calls, 2);
      expect(cache.value, 2);
    });

    test('corrupt persisted bytes are ignored', () async {
      final store = MemorySnapshotStore()..values['k'] = '{not json';
      final cache = SnapshotCache<int>(
        key: 'k',
        host: SnapshotHost.detached(store),
        decode: (j) => j['n']! as int,
        encode: (v) => {'n': v},
      );
      await cache.refresh(() async => throw StateError('offline'));
      expect(cache.value, isNull);
    });
  });

  group('ApiQuestsRepository', () {
    test('maps daily, monthly and friends quests; empty before load', () async {
      transport.json(
        'GET /base/v1/quests',
        page([
          quest('daily_lessons', 'DAY', target: 2, metric: 1),
          quest('daily_correct', 'DAY', target: 15, metric: 15),
          quest('daily_review', 'DAY', target: 1, claimed: true, metric: 1),
          quest('monthly_active_days', 'MONTH', target: 20, metric: 7, gems: 0),
          quest('friend_lessons10', 'WEEK', target: 10, metric: 3, gems: 10),
        ]),
      );
      final repo = ApiQuestsRepository(
        api,
        now: () => DateTime(2026, 10, 12, 19, 30),
      );
      final first = repo.loadQuests();
      expect(first.dailyQuests, isEmpty, reason: 'no fixtures in API mode');
      await settle();
      await settle();
      final state = repo.loadQuests();
      expect(state.dailyQuests.map((q) => q.title), [
        'Complete 2 lessons',
        'Answer 15 questions correctly',
        'Complete 1 review session',
      ]);
      expect(state.dailyQuests.map((q) => q.chestType), QuestChestType.values);
      expect(state.dailyQuests[1].canClaim, isTrue);
      expect(state.dailyQuests[2].isClaimed, isTrue);
      expect(state.dailyQuests.first.rewardGems, 5);
      expect(state.monthlyChallenge.title, 'October Quest');
      expect(state.monthlyChallenge.currentPoints, 7);
      expect(state.monthlyChallenge.targetPoints, 20);
      expect(state.monthlyChallenge.daysRemaining, '20 DAYS');
      expect(state.friendsQuest.target, 10);
      expect(state.friendsQuest.userLessons, 3);
      expect(state.dailyTimeRemaining, '4H');
      expect(state.weekendQuest.currentXp, 0);
    });

    test(
      'claims a completed quest with its period key, then refreshes',
      () async {
        transport
          ..json(
            'GET /base/v1/quests',
            page([
              quest('daily_lessons', 'DAY', target: 2, metric: 2),
              quest('daily_review', 'DAY', target: 1),
            ]),
          )
          ..json('POST /base/v1/quests/daily_lessons/claim', rewards());
        final repo = ApiQuestsRepository(api);
        await repo.refresh();
        expect(await repo.claim('daily_review'), isFalse, reason: 'not done');
        expect(await repo.claim('daily_lessons'), isTrue);
        final claims = transport.to('POST /base/v1/quests/daily_lessons/claim');
        expect(bodyOf(claims.single), {'periodKey': '2026-10-12'});
        expect(claims.single.headers['Idempotency-Key'], isNotNull);
        await settle();
        expect(transport.to('GET /base/v1/quests'), hasLength(2));
      },
    );
  });

  test('ApiAchievementsRepository maps server tracks, no fixtures', () async {
    transport
      ..json('GET /base/v1/me', profile(achievements: ['lessons']))
      ..json('GET /base/v1/me/rewards', rewards(streak: 4));
    final repo = ApiAchievementsRepository(api);
    expect(repo.loadAchievements(), isEmpty);
    expect(repo.loadMonthlyBadges(), isEmpty);
    await repo.refresh();
    final list = repo.loadAchievements();
    expect(list.map((a) => a.id), ['streak', 'lessons']);
    expect(list.first.progress, 4);
    expect(list.first.goal, 7, reason: 'next streak tier after 3');
    expect(list.last.progress, 5, reason: 'earned first lessons tier');
    expect(list.last.goal, 20);
    expect(
      repo.loadMonthlyBadges(),
      isEmpty,
      reason: 'no monthly ids means no badges, never archived fixtures',
    );
  });

  test('ApiAchievementsRepository maps monthly_YYYY_MM badges', () async {
    transport
      ..json(
        'GET /base/v1/me',
        profile(
          achievements: [
            'streak',
            'monthly_2026_10',
            'monthly_2025_12',
            'monthly_2026_02',
            'monthly_2024_03',
            'monthly_2026_13',
            'monthly_badges',
          ],
        ),
      )
      ..json('GET /base/v1/me/rewards', rewards(streak: 4));
    final repo = ApiAchievementsRepository(api);
    expect(repo.loadMonthlyBadges(), isEmpty, reason: 'empty before load');
    await repo.refresh();
    final badges = repo.loadMonthlyBadges();
    expect(badges.map((b) => '${b.year} ${b.month}'), [
      '2024 March',
      '2025 December',
      '2026 February',
      '2026 October',
    ], reason: 'chronological, malformed ids ignored');
    expect(badges.every((b) => b.earned), isTrue);
    expect(badges.first.art.file, 'achievement-monthly-history');
    expect(badges.last.art.file, 'achievement-monthly-2025');
    expect(badges.last.art.source.width, greaterThan(0));
  });

  test(
    'ApiPracticeRepository lists words newest-first and open mistakes',
    () async {
      Map<String, Object?> word(
        String id,
        String term,
        String? vi,
        String? at,
      ) => {
        'courseId': 'vi_en',
        'vocabularyId': id,
        'skillId': 'u1.vocab',
        'term': term,
        'translation': vi,
        'stage': 1,
        'strength': 2,
        'halfLifeHours': 24,
        'correctCount': 3,
        'incorrectCount': 1,
        'firstSeenAt': '2026-10-01T00:00:00.000Z',
        'lastReviewedAt': at,
        'dueAt': _iso,
      };
      Map<String, Object?> mistake(String id, {String? resolved}) => {
        'courseId': 'vi_en',
        'exerciseId': id,
        'lessonVersion': 'v2',
        'skillId': 'u1.vocab',
        'mistakeCount': 2,
        'lastMistakeAt': _iso,
        'resolvedAt': resolved,
      };
      transport
        ..json(
          'GET /v1/words',
          page([
            word('u1.hello', 'hello', 'xin chào', '2026-10-05T00:00:00.000Z'),
            word('u1.cat', 'cat', null, '2026-10-11T00:00:00.000Z'),
            word('u1.dog', 'dog', 'con chó', null),
          ]),
        )
        ..json(
          'GET /v1/mistakes',
          page([mistake('e1'), mistake('e2', resolved: _iso)]),
        );
      final repo = ApiPracticeRepository(api, course);
      await repo.refresh();
      expect(repo.loadWords().map((w) => [w.term, w.meaning]), [
        ['cat', ''],
        ['hello', 'xin chào'],
        ['dog', 'con chó'],
      ]);
      expect(repo.loadMistakes().map((m) => m.exerciseId), ['e1']);
      expect(transport.to('GET /v1/words').single.uri.queryParameters, {
        'courseId': 'vi_en',
        'limit': '100',
      });
    },
  );

  group('ApiNotificationRepository', () {
    test('loads server preferences and saves with expectedRevision', () async {
      transport
        ..json(
          'GET /base/v1/me/preferences',
          preferences(off: ['promotions.email']),
        )
        ..on(
          'PATCH /base/v1/me/preferences',
          (r) => jsonResponse(
            preferences(
              off: List<String>.from(bodyOf(r)['notificationsOff']! as List),
              revision: 5,
            ),
          ),
        );
      final repo = ApiNotificationRepository(api);
      expect(repo.load(), repo.defaults);
      await repo.refresh();
      final prefs = repo.load();
      expect(prefs.off, {'promotions.email'});
      expect(prefs.reminderTime.label, '7:30 PM');
      expect(prefs.smartScheduling, isTrue);
      await repo.save(prefs.copyWith(off: {'promotions.email', 'events.push'}));
      final body = bodyOf(transport.to('PATCH /base/v1/me/preferences').single);
      expect(body['expectedRevision'], 4);
      expect(body['notificationsOff'], ['events.push', 'promotions.email']);
      expect(body['reminderMinute'], 1170);
      expect(repo.load().off, {'events.push', 'promotions.email'});
      expect(repo.categories, isNotEmpty);
    });

    test(
      'a notification conflict requires refresh before a new command',
      () async {
        transport
          ..once(
            'GET /base/v1/me/preferences',
            (_) => jsonResponse(preferences(revision: 4)),
          )
          ..json('GET /base/v1/me/preferences', preferences(revision: 9))
          ..once(
            'PATCH /base/v1/me/preferences',
            (_) =>
                jsonResponse(errorEnvelope('REVISION_CONFLICT'), status: 409),
          )
          ..on(
            'PATCH /base/v1/me/preferences',
            (r) => jsonResponse(preferences(revision: 10)),
          );
        final repo = ApiNotificationRepository(api);
        await expectLater(
          repo.save(const NotificationPrefs()),
          throwsA(isA<ApiException>()),
        );
        expect(transport.to('PATCH /base/v1/me/preferences'), hasLength(1));
        await repo.fetch();
        await repo.save(const NotificationPrefs());
        final patches = transport.to('PATCH /base/v1/me/preferences');
        expect(patches, hasLength(2));
        expect(bodyOf(patches.first)['expectedRevision'], 4);
        expect(bodyOf(patches.last)['expectedRevision'], 9);
      },
    );
  });

  group('progress snapshot consumers', () {
    test('league ranking and unseen result; seen marks the week', () async {
      progressRoutes();
      transport.json('POST /base/v1/league/result/seen', receipt());
      final source = ProgressSnapshotSource(api);
      final repo = ApiLeagueRepository(source);
      expect(repo.ranking()!.entries, isEmpty);
      expect(repo.lastResult(), isNull);
      await source.refresh();
      final ranking = repo.ranking()!;
      expect(ranking.entries.map((e) => e.name), [
        'Linh',
        'Minh',
        'Thanh',
        'Lan',
      ]);
      expect(ranking.entries.where((e) => e.isOwn).single.rank, 3);
      final result = repo.lastResult()!;
      expect(result.previousTier, LeagueTier.bronze);
      expect(result.currentTier, LeagueTier.silver);
      expect(result.rewardGems, 30);
      expect(result.learner.rank, 2);
      await repo.markResultSeen();
      expect(bodyOf(transport.to('POST /base/v1/league/result/seen').single), {
        'weekId': '2026-W41',
      });
    });

    test('a learner outside any cohort gets an empty league', () async {
      progressRoutes(inLeague: false, result: leagueResult(unseen: false));
      final source = ProgressSnapshotSource(api);
      await source.refresh();
      expect(source.cache.error, isNull);
      expect(ApiLeagueRepository(source).ranking()!.entries, isEmpty);
      expect(ApiLeagueRepository(source).lastResult(), isNull);
    });

    test('results chain values come from rewards, quests and league', () async {
      progressRoutes();
      final source = ProgressSnapshotSource(api);
      await source.refresh();
      final repo = ApiResultsRepository(
        source,
        now: () => DateTime(2026, 10, 15), // Thursday
      );
      final streak = repo.streakExtended();
      expect(streak.days, 4);
      expect(streak.week.map((d) => d.state), [
        ResultDayState.practiced,
        ResultDayState.practiced,
        ResultDayState.practiced,
        ResultDayState.today,
        ResultDayState.missed,
        ResultDayState.missed,
        ResultDayState.missed,
      ]);
      expect(repo.gemReward().gems, 420);
      final quests = repo.questProgress();
      expect(quests.quests.single.chest, QuestChestState.gold);
      expect(quests.gemBalance, 420);
      final rank = repo.leagueRank();
      expect(rank.promotionCutoff, 5);
      expect(rank.user!.rank, 3);
      expect(rank.rows.first.rank, 2);
      expect(repo.friendsQuest()!.remaining, 6);
      expect(repo.streakGoal(), isNull);
      expect(repo.widgetUnlock(), isNull);
      expect(repo.friendStreak(), isNull);
      expect(repo.pathReturn().gems, 420);
    });

    test(
      'shell stats use server streak, gems and energy once loaded',
      () async {
        progressRoutes();
        transport.json('GET /v1/me/energy', energy(mode: 'UNLIMITED'));
        final source = ProgressSnapshotSource(api);
        final repo = ApiAppShellRepository(source);
        const local = AppShellSnapshot(
          score: 12,
          streak: 0,
          gems: 5,
          energy: 25,
          unlimited: false,
          streakActive: false,
        );
        expect(repo.stats(local)[2].value, '—', reason: 'no fixture balance');
        await source.refresh();
        final stats = repo.stats(local);
        expect(stats.map((s) => s.value), ['12', '4', '420', '∞']);
        expect(stats[1].active, isTrue);
      },
    );
  });

  group('conversations', () {
    test(
      'roleplay progress maps server scenario history onto library cards',
      () async {
        transport.json(
          'GET /v1/conversations',
          page([
            conversation('c1', 'rp_restaurant_dinner', stars: 1, words: 8),
            conversation('c2', 'rp_restaurant_dinner', stars: 3, words: 5),
            conversation('c3', 'rp_hotel_check_in', status: 'ABANDONED'),
            conversation('c4', 'rp_doctor_visit'),
          ]),
        );
        final repo = ApiRoleplayRepository(api, course);
        expect(repo.initialProgress(), isEmpty);
        await repo.refresh();
        final progress = repo.initialProgress();
        expect(progress.keys, ['restaurant']);
        expect(progress['restaurant']!.stars, 3);
        expect(progress['restaurant']!.bestWords, 8);
        expect(progress['restaurant']!.completions, 2);
        expect(repo.topics(), isNotEmpty, reason: 'catalog stays bundled');
      },
    );

    test('video call opens a TURN voice session and a bound VIDEO_CALL conversation', () async {
      transport
        ..json('POST /v1/voice-sessions', {
          'sessionId': '00000000-0000-4000-8000-000000000001',
          'mode': 'TURN',
          'providerAlias': 'scripted',
          'model': 'scripted-v1',
          'ephemeralToken': null,
          'connectExpiresAt': null,
          'sessionExpiresAt': '2026-10-12T08:30:00.000Z',
          'epoch': 0,
          'inputSampleRate': 16000,
          'outputSampleRate': 24000,
          'configVersion': 'cfg-1',
        })
        ..json(
          'POST /v1/conversations',
          conversation(
            'v1',
            'rp_daily_routine',
            status: 'ACTIVE',
            kind: 'VIDEO_CALL',
          ),
        )
        ..json(
          'POST /v1/conversations/v1/complete',
          conversation('v1', 'rp_daily_routine', kind: 'VIDEO_CALL'),
        );
      final repo = ApiCallRepository(api, course);
      final session = await repo.loadSession('lily');
      expect(session.id, 'v1');
      expect(session.script, isNotEmpty);
      await repo.completeCall(session.id, 0);
      expect(
        bodyOf(transport.to('POST /v1/conversations/v1/complete').single),
        {'endReason': 'USER_EXIT'},
      );
    });
  });

  test('ApiSocialRepository maps friend streaks and sends commands', () async {
    Map<String, Object?> streak(
      String pair,
      String friend,
      String inviter,
      String status,
    ) => {
      'pairId': pair,
      'friendUserId': friend,
      'friendNickname': friend.toUpperCase(),
      'inviterId': inviter,
      'status': status,
      'length': status == 'ACTIVE' ? 12 : 0,
      'startDay': null,
      'lastExtendedDay': null,
      'extendedToday': false,
    };
    transport
      ..json(
        'GET /base/v1/friend-streaks',
        page([
          streak('p1', 'a', 'me', 'ACTIVE'),
          streak('p2', 'b', 'b', 'PENDING'),
          streak('p3', 'c', 'me', 'PENDING'),
          streak('p4', 'd', 'me', 'ENDED'),
        ]),
      )
      ..json(
        'POST /base/v1/friend-streaks/p2/respond',
        streak('p2', 'b', 'b', 'ACTIVE'),
      )
      ..json('POST /base/v1/blocks', receipt())
      ..json('DELETE /base/v1/blocks/x', receipt())
      ..json('POST /base/v1/interactions', {
        'operationId': 'op',
        'toUserId': 'a',
        'kind': 'NUDGE',
        'contextId': 'q1',
        'day': '2026-10-12',
        'gemsCost': 0,
        'gems': 420,
      });
    final repo = ApiSocialRepository(api);
    expect(const MockSocialRepository().friendStreaks(), isNull);
    await repo.refresh();
    final links = repo.friendStreaks()!;
    expect(links.map((l) => [l.userId, l.state]), [
      ['a', FriendStreakState.active],
      ['b', FriendStreakState.pendingIncoming],
      ['c', FriendStreakState.pendingOutgoing],
    ]);
    await repo.respondFriendStreak('b', accept: true);
    expect(
      bodyOf(transport.to('POST /base/v1/friend-streaks/p2/respond').single),
      {'accept': true},
    );
    await repo.sendInteraction('a', SocialInteraction.nudge, contextId: 'q1');
    expect(bodyOf(transport.to('POST /base/v1/interactions').single), {
      'targetUserId': 'a',
      'kind': 'NUDGE',
      'contextId': 'q1',
      'messageKey': 'nudge.default',
    });
    await repo.block('x');
    await repo.unblock('x');
    expect(transport.to('DELETE /base/v1/blocks/x'), hasLength(1));
  });

  group('ApiPathRepository', () {
    Map<String, Object?> node(
      int order,
      String unit,
      String state, {
      String section = 's1',
    }) => {
      'nodeId': 'n$order',
      'unitId': unit,
      'sectionId': section,
      'order': order,
      'title': 'Node $order',
      'kind': 'lesson',
      'state': state,
      'lessonIds': ['n${order}l1', 'n${order}l2'],
    };
    Map<String, Object?> path(
      List<Object?> nodes, {
      List<String> done = const [],
    }) => {
      'enrollment': {
        'courseId': 'vi_en',
        'courseVersion': 'v2',
        'frontierNodeOrder': 2,
        'completedLessonIds': done,
        'masteredNodeIds': <String>[],
        'revision': 1,
      },
      'nodes': nodes,
      'asOf': _iso,
      'nextCursor': null,
    };

    test('maps the shown unit onto node-<i> progress', () async {
      transport.json(
        'GET /v1/courses/vi_en/path',
        path(
          [
            node(0, 'u1', 'completed'),
            node(1, 'u1', 'mastered'),
            node(2, 'u1', 'current'),
            node(3, 'u1', 'locked'),
            node(4, 'u2', 'locked'),
            node(5, 'u3', 'locked', section: 's2'),
          ],
          done: ['n0l1', 'n0l2', 'n1l1', 'n1l2', 'n2l1'],
        ),
      );
      final repo = ApiPathRepository(api, course);
      expect(repo.unitProgress(const CourseTarget(1, 1)), isNull);
      await repo.refresh();
      final unit = repo.unitProgress(const CourseTarget(1, 1))!;
      expect(unit.completedNodes, {'node-0', 'node-1'});
      expect(unit.currentNode, 2);
      expect(unit.lessonInNode, 1);
      expect(unit.completedLessons, 5);
      final next = repo.unitProgress(const CourseTarget(1, 2))!;
      expect(next.completedNodes, isEmpty);
      expect(next.currentNode, 0);
      expect(repo.unitProgress(const CourseTarget(2, 1)), isNotNull);
      expect(repo.unitProgress(const CourseTarget(3, 1)), isNull);
    });

    test(
      'follows path pages and persists them for the next cold start',
      () async {
        final store = MemorySnapshotStore();
        transport
          ..once(
            'GET /v1/courses/vi_en/path',
            (_) => jsonResponse({
              ...path([node(0, 'u1', 'completed')]),
              'nextCursor': 'page2',
            }),
          )
          ..json(
            'GET /v1/courses/vi_en/path',
            path([node(1, 'u1', 'current')]),
          );
        final repo = ApiPathRepository(
          api,
          course,
          host: SnapshotHost.detached(store),
        );
        await repo.refresh();
        expect(repo.unitProgress(const CourseTarget(1, 1))!.currentNode, 1);
        expect(store.values['path'], isNotNull);

        final cold = ApiPathRepository(
          api,
          course,
          host: SnapshotHost.detached(store),
        );
        transport.offline = true;
        await cold.refresh();
        expect(cold.unitProgress(const CourseTarget(1, 1))!.completedNodes, {
          'node-0',
        });
      },
    );
  });

  test('ActiveCourse resolves the first available course once', () async {
    transport.json(
      'GET /v1/courses',
      page([
        {
          'courseId': 'old',
          'title': 'Old',
          'sourceLocale': 'vi',
          'targetLocale': 'en',
          'publishedVersion': 'v1',
          'available': false,
        },
        {
          'courseId': 'vi_en',
          'title': 'English',
          'sourceLocale': 'vi',
          'targetLocale': 'en',
          'publishedVersion': 'v2',
          'available': true,
        },
      ]),
    );
    final resolver = ActiveCourse(api);
    expect(await Future.wait([resolver.id(), resolver.id()]), [
      'vi_en',
      'vi_en',
    ]);
    expect(await resolver.id(), 'vi_en');
    expect(transport.to('GET /v1/courses'), hasLength(1));
  });

  test('wire DTO snapshots round-trip through the store', () {
    final snapshot = ProgressSnapshot.fromJson({
      'profile': profile(),
      'rewards': rewards(),
      'energy': energy(),
      'league': null,
      'leagueResult': leagueResult(),
      'quests': page(<Object?>[]),
    });
    final again = ProgressSnapshot.fromJson(
      Map<String, Object?>.from(
        jsonDecode(jsonEncode(snapshot.toJson())) as Map,
      ),
    );
    expect(again.league, isNull);
    expect(again.rewards.gems, 420);
    expect(wire.Preferences.fromJson(preferences()).revision, 4);
  });
}
