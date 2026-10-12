import 'package:cocenglish/features/notifications/domain/notification_models.dart';
import 'package:cocenglish/features/reminders/domain/reminder_copy.dart';
import 'package:cocenglish/features/reminders/domain/reminder_models.dart';
import 'package:cocenglish/features/reminders/domain/reminder_planner.dart';
import 'package:cocenglish/features/reminders/domain/streak_home_widget.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location hcm, ny;
  setUpAll(() {
    tzdata.initializeTimeZones();
    hcm = tz.getLocation('Asia/Ho_Chi_Minh');
    ny = tz.getLocation('America/New_York');
  });

  tz.TZDateTime at(tz.Location l, int y, int mo, int d, int h, [int mi = 0]) =>
      tz.TZDateTime(l, y, mo, d, h, mi);

  ReminderInputs inputs(
    tz.TZDateTime now, {
    NotificationPrefs prefs = const NotificationPrefs(),
    int streak = 0,
    bool practicedToday = false,
    int freezeSlots = 0,
    List<String> friends = const [],
    String? week,
    ReminderTime? smart,
  }) => ReminderInputs(
    now: now,
    prefs: prefs,
    streak: streak,
    practicedToday: practicedToday,
    freezeSlots: freezeSlots,
    friendStreakNames: friends,
    leagueWeekId: week,
    smartTime: smart,
  );

  Iterable<PlannedReminder> ofKind(List<PlannedReminder> p, ReminderKind k) =>
      p.where((r) => r.kind == k);

  group('daily reminder', () {
    test('today at the chosen time plus the next six days, stable ids', () {
      final plan = ReminderPlanner.plan(
        inputs(
          at(hcm, 2026, 10, 12, 9),
          prefs: const NotificationPrefs(reminderTime: ReminderTime(19, 15)),
        ),
      );
      final daily = ofKind(plan, ReminderKind.daily).toList();
      expect(daily, hasLength(7));
      expect(daily.map((r) => r.id), [100, 101, 102, 103, 104, 105, 106]);
      expect(daily.first.at, at(hcm, 2026, 10, 12, 19, 15));
      expect(daily.last.at, at(hcm, 2026, 10, 18, 19, 15));
      expect(daily.every((r) => r.link == ReminderLinks.lesson), isTrue);
    });

    test('skips today once a lesson is done or the time has passed', () {
      final done = ReminderPlanner.plan(
        inputs(at(hcm, 2026, 10, 12, 9), practicedToday: true),
      );
      expect(
        ofKind(done, ReminderKind.daily).map((r) => r.id),
        isNot(contains(100)),
      );
      final late = ReminderPlanner.plan(inputs(at(hcm, 2026, 10, 12, 18)));
      expect(ofKind(late, ReminderKind.daily).first.id, 101);
    });

    test('push toggle off removes it', () {
      final plan = ReminderPlanner.plan(
        inputs(
          at(hcm, 2026, 10, 12, 9),
          prefs: const NotificationPrefs(off: {'practice.push'}),
        ),
      );
      expect(ofKind(plan, ReminderKind.daily), isEmpty);
    });

    test('smart scheduling uses the learned time, kept out of quiet hours', () {
      expect(ReminderPlanner.smartTime([1200, 1210]), isNull);
      expect(
        ReminderPlanner.smartTime([1200, 1230, 1215, 600, 1220]),
        const ReminderTime(20, 0),
      );
      final plan = ReminderPlanner.plan(
        inputs(
          at(hcm, 2026, 10, 12, 9),
          prefs: const NotificationPrefs(smartScheduling: true),
          smart: const ReminderTime(23, 30),
        ),
      );
      // 23:30 is quiet; the learned time moves to the end of quiet hours.
      expect(
        ofKind(plan, ReminderKind.daily).first.at,
        at(hcm, 2026, 10, 13, 8),
      );
    });

    test('a user-chosen late time is honoured as chosen', () {
      final plan = ReminderPlanner.plan(
        inputs(
          at(hcm, 2026, 10, 12, 9),
          prefs: const NotificationPrefs(reminderTime: ReminderTime(23, 0)),
        ),
      );
      expect(
        ofKind(plan, ReminderKind.daily).first.at,
        at(hcm, 2026, 10, 12, 23),
      );
    });
  });

  group('copy rotation', () {
    test('consecutive days never repeat and a replan keeps the same line', () {
      final plan = ReminderPlanner.plan(inputs(at(hcm, 2026, 10, 12, 9)));
      final titles = ofKind(
        plan,
        ReminderKind.daily,
      ).map((r) => r.title).toList();
      for (var i = 1; i < titles.length; i++) {
        expect(titles[i], isNot(titles[i - 1]));
      }
      final again = ReminderPlanner.plan(inputs(at(hcm, 2026, 10, 12, 11)));
      expect(ofKind(again, ReminderKind.daily).map((r) => r.title), titles);
    });

    test('every pool line is Vietnamese, filled, and pools rotate fully', () {
      final pools = [
        ReminderCopy.daily,
        ReminderCopy.dailyWithStreak,
        ReminderCopy.comeback,
        ReminderCopy.streakAtRisk,
        ReminderCopy.friendStreak,
        ReminderCopy.leagueEnding,
        ReminderCopy.streakFreezeUsed,
        ReminderCopy.leaguePromoted,
      ];
      for (final pool in pools) {
        expect(pool.length, greaterThanOrEqualTo(2));
        final seen = {
          for (var d = 0; d < pool.length; d++)
            ReminderCopy.pick(
              pool,
              ReminderKind.daily,
              d,
              streak: 4,
              friend: 'An',
            ).title,
        };
        expect(seen, hasLength(pool.length));
        for (final t in seen) {
          expect(t, isNot(contains('{')));
        }
      }
    });

    test('streak copy, milestone and comeback lines', () {
      final plan = ReminderPlanner.plan(
        inputs(at(hcm, 2026, 10, 12, 9), streak: 29),
      );
      final today = ofKind(plan, ReminderKind.daily).first;
      expect('${today.title} ${today.body}', contains('30'));
      final daily = ofKind(plan, ReminderKind.daily).toList();
      final comeback = ReminderCopy.comeback.map((l) => l.title).toSet();
      expect(comeback, contains(daily[3].title));
      expect(isStreakMilestone(30), isTrue);
      expect(isStreakMilestone(31), isFalse);
      expect(isStreakMilestone(400), isTrue);
    });
  });

  group('streak at risk', () {
    test('this evening when there is a streak and no lesson yet', () {
      final plan = ReminderPlanner.plan(
        inputs(at(hcm, 2026, 10, 12, 9), streak: 12),
      );
      final risk = ofKind(plan, ReminderKind.streakAtRisk).single;
      expect(risk.id, 200);
      expect(risk.at, at(hcm, 2026, 10, 12, 20, 30));
      expect(risk.title + risk.body, contains('12'));
      expect(risk.link, ReminderLinks.streak);
    });

    test(
      'is not planned after a lesson (cancel-on-complete set covers it)',
      () {
        final plan = ReminderPlanner.plan(
          inputs(at(hcm, 2026, 10, 12, 9), streak: 12, practicedToday: true),
        );
        expect(ofKind(plan, ReminderKind.streakAtRisk), isEmpty);
        expect(ReminderPlanner.cancelOnLessonComplete, contains(200));
        expect(ReminderPlanner.cancelOnLessonComplete, contains(100));
      },
    );

    test('no streak, toggle off or evening over: nothing', () {
      expect(
        ofKind(
          ReminderPlanner.plan(inputs(at(hcm, 2026, 10, 12, 9))),
          ReminderKind.streakAtRisk,
        ),
        isEmpty,
      );
      expect(
        ofKind(
          ReminderPlanner.plan(
            inputs(
              at(hcm, 2026, 10, 12, 9),
              streak: 3,
              prefs: const NotificationPrefs(off: {'streak_saver.push'}),
            ),
          ),
          ReminderKind.streakAtRisk,
        ),
        isEmpty,
      );
      expect(
        ofKind(
          ReminderPlanner.plan(
            inputs(at(hcm, 2026, 10, 12, 21, 45), streak: 3),
          ),
          ReminderKind.streakAtRisk,
        ),
        isEmpty,
      );
    });

    test('follows a late daily reminder but stays before quiet hours', () {
      final plan = ReminderPlanner.plan(
        inputs(
          at(hcm, 2026, 10, 12, 9),
          streak: 5,
          prefs: const NotificationPrefs(reminderTime: ReminderTime(21, 0)),
        ),
      );
      // daily + 1h = 22:00 is quiet → pulled to 21:30.
      expect(
        ofKind(plan, ReminderKind.streakAtRisk).single.at,
        at(hcm, 2026, 10, 12, 21, 30),
      );
    });

    test('mentions the freeze when one is equipped', () {
      final plan = ReminderPlanner.plan(
        inputs(at(hcm, 2026, 10, 12, 9), streak: 5, freezeSlots: 1),
      );
      final r = ofKind(plan, ReminderKind.streakAtRisk).single;
      final freezeTitles = ReminderCopy.streakAtRiskWithFreeze
          .map((l) => l.title.replaceAll('{streak}', '5'))
          .toSet();
      expect(freezeTitles, contains(r.title));
    });
  });

  group('quiet hours', () {
    const quiet = QuietHours();
    test('wraps midnight', () {
      expect(quiet.contains(DateTime(2026, 1, 1, 22)), isTrue);
      expect(quiet.contains(DateTime(2026, 1, 1, 3)), isTrue);
      expect(quiet.contains(DateTime(2026, 1, 1, 7, 59)), isTrue);
      expect(quiet.contains(DateTime(2026, 1, 1, 8)), isFalse);
      expect(quiet.contains(DateTime(2026, 1, 1, 21, 59)), isFalse);
    });
    test('before/after move to the right side of the window', () {
      expect(
        quiet.before(at(hcm, 2026, 10, 13, 2)),
        at(hcm, 2026, 10, 12, 21, 30),
      );
      expect(
        quiet.before(at(hcm, 2026, 10, 12, 23)),
        at(hcm, 2026, 10, 12, 21, 30),
      );
      expect(quiet.after(at(hcm, 2026, 10, 12, 23)), at(hcm, 2026, 10, 13, 8));
      expect(quiet.after(at(hcm, 2026, 10, 13, 2)), at(hcm, 2026, 10, 13, 8));
      expect(quiet.after(at(hcm, 2026, 10, 13, 12)), at(hcm, 2026, 10, 13, 12));
    });
  });

  group('league and friends', () {
    test('league ending lands before quiet hours on Sunday in Vietnam', () {
      // Week 2026-10-12 closes Monday 2026-10-19 00:00 UTC = 07:00 ICT;
      // minus 6h = 01:00 (quiet) → Sunday 21:30.
      final plan = ReminderPlanner.plan(
        inputs(at(hcm, 2026, 10, 14, 9), week: '2026-10-12'),
      );
      final r = ofKind(plan, ReminderKind.leagueEnding).single;
      expect(r.at, at(hcm, 2026, 10, 18, 21, 30));
      expect(r.link, ReminderLinks.league);
    });

    test('league ending in New York keeps the six hour lead', () {
      final plan = ReminderPlanner.plan(
        inputs(at(ny, 2026, 10, 14, 9), week: '2026-10-12'),
      );
      // 2026-10-19 00:00Z - 6h = 18:00Z = 14:00 EDT Sunday.
      expect(
        ofKind(plan, ReminderKind.leagueEnding).single.at,
        at(ny, 2026, 10, 18, 14),
      );
    });

    test('friend streak nudge at 19:00 names the friend', () {
      final plan = ReminderPlanner.plan(
        inputs(at(hcm, 2026, 10, 12, 9), friends: ['Lan']),
      );
      final r = ofKind(plan, ReminderKind.friendStreak).single;
      expect(r.at, at(hcm, 2026, 10, 12, 19));
      expect(r.title + r.body, contains('Lan'));
    });
  });

  group('timezone', () {
    test('times are wall-clock in the device zone, DST-correct', () {
      // US DST ends 2026-11-01; 19:00 stays 19:00 local on both sides.
      final plan = ReminderPlanner.plan(
        inputs(
          at(ny, 2026, 10, 30, 9),
          prefs: const NotificationPrefs(reminderTime: ReminderTime(19, 0)),
        ),
      );
      final daily = ofKind(plan, ReminderKind.daily).toList();
      for (final r in daily) {
        expect(r.at.hour, 19);
        expect(r.at.location, ny);
      }
      expect(daily[0].at.timeZoneOffset, const Duration(hours: -4));
      expect(daily[3].at.timeZoneOffset, const Duration(hours: -5));
    });

    test('the same instant replans to the new zone wall clock', () {
      final instant = DateTime.utc(2026, 10, 12, 2);
      final inHcm = ReminderPlanner.plan(
        inputs(tz.TZDateTime.from(instant, hcm)),
      );
      final inNy = ReminderPlanner.plan(
        inputs(tz.TZDateTime.from(instant, ny)),
      );
      expect(inHcm.first.at.hour, 17);
      expect(inNy.first.at.hour, 17);
      expect(inHcm.first.at.isAtSameMomentAs(inNy.first.at), isFalse);
    });
  });

  group('events', () {
    final now = tz.TZDateTime(tz.UTC, 2026, 10, 12, 5); // 12:00 ICT
    test(
      'freeze consumption fires once, and only when the streak survived',
      () {
        final events = ReminderPlanner.events(
          previous: const ReminderSnapshot(streak: 9, freezeSlots: 2),
          current: const ReminderSnapshot(streak: 9, freezeSlots: 1),
          prefs: const NotificationPrefs(),
          now: tz.TZDateTime.from(now, hcm),
        );
        expect(events.single.kind, ReminderKind.streakFreezeUsed);
        expect(events.single.immediate, isTrue);
        expect(
          ReminderPlanner.events(
            previous: const ReminderSnapshot(streak: 9, freezeSlots: 1),
            current: const ReminderSnapshot(streak: 9, freezeSlots: 1),
            prefs: const NotificationPrefs(),
            now: tz.TZDateTime.from(now, hcm),
          ),
          isEmpty,
        );
        expect(
          ReminderPlanner.events(
            previous: null,
            current: const ReminderSnapshot(streak: 9, freezeSlots: 1),
            prefs: const NotificationPrefs(),
            now: tz.TZDateTime.from(now, hcm),
          ),
          isEmpty,
        );
      },
    );

    test('promotion fires for a new week and waits out quiet hours', () {
      final events = ReminderPlanner.events(
        previous: const ReminderSnapshot(
          streak: 1,
          freezeSlots: 0,
          lastLeagueWeekId: '2026-09-28',
        ),
        current: const ReminderSnapshot(
          streak: 1,
          freezeSlots: 0,
          lastLeagueWeekId: '2026-10-05',
          lastLeagueOutcome: 'PROMOTED',
        ),
        prefs: const NotificationPrefs(),
        now: at(hcm, 2026, 10, 12, 23),
      );
      final e = events.single;
      expect(e.kind, ReminderKind.leaguePromoted);
      expect(e.immediate, isFalse);
      expect(e.at, at(hcm, 2026, 10, 13, 8));
      expect(e.link, ReminderLinks.league);
    });

    test('preferences gate events', () {
      final events = ReminderPlanner.events(
        previous: const ReminderSnapshot(streak: 9, freezeSlots: 2),
        current: const ReminderSnapshot(streak: 9, freezeSlots: 1),
        prefs: const NotificationPrefs(off: {'streak_freeze.push'}),
        now: tz.TZDateTime.from(now, hcm),
      );
      expect(events, isEmpty);
    });
  });

  test('deep links are sanitized to known screens', () {
    expect(ReminderLinks.sanitize('/streak'), '/streak');
    expect(ReminderLinks.sanitize('/league'), '/league');
    expect(ReminderLinks.sanitize('https://evil.example'), '/home');
    expect(ReminderLinks.sanitize(null), '/home');
  });

  test('home widget data: flame state and goal progress', () {
    final lit = StreakHomeWidgetData.from(
      streak: 4,
      practicedToday: true,
      goalMinutes: 10,
      todayMinutes: 6,
    );
    expect(lit.flame, WidgetFlame.lit);
    expect(lit.goalPercent, 60);
    final risk = StreakHomeWidgetData.from(
      streak: 4,
      practicedToday: false,
      goalMinutes: 10,
      todayMinutes: 0,
    );
    expect(risk.flame, WidgetFlame.atRisk);
    expect(risk.toStorage()['coc_flame'], 'atRisk');
    final none = StreakHomeWidgetData.from(
      streak: 0,
      practicedToday: false,
      goalMinutes: 0,
      todayMinutes: 50,
    );
    expect(none.flame, WidgetFlame.none);
    expect(none.goalPercent, 100);
  });
}
