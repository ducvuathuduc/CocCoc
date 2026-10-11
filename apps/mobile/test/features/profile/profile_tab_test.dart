import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/profile/profile_mock.dart';
import 'package:cocenglish/features/profile/profile_tab_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _pump(ProfileMock profile, {double textScale = 1}) => MaterialApp(
  theme: referenceTheme(),
  home: MediaQuery(
    data: const MediaQueryData().copyWith(
      textScaler: TextScaler.linear(textScale),
    ),
    child: ProfileTabScreen(profile: profile),
  ),
);

void main() {
  testWidgets('new profile header, stats and finish card render', (
    tester,
  ) async {
    await tester.pumpWidget(_pump(profileMockNew));
    await tester.pumpAndSettle();

    expect(find.text('Sam Lee'), findsOneWidget);
    expect(find.text('@SAMLEE782112 · JOINED 2025'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-courses')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-following')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-followers')), findsOneWidget);
    expect(find.text('ADD FRIENDS'), findsOneWidget);
    expect(find.text('Finish your profile!'), findsOneWidget);
    expect(find.text('1 STEP LEFT'), findsOneWidget);
    expect(find.text('COMPLETE PROFILE'), findsOneWidget);
    expect(find.text('OVERVIEW'), findsOneWidget);
    expect(find.text('1 day'), findsOneWidget);
    expect(find.text('24 XP'), findsOneWidget);
  });

  testWidgets('rich profile stats, friend streaks and badges render', (
    tester,
  ) async {
    await tester.pumpWidget(_pump(profileMockRich));
    await tester.pumpAndSettle();

    expect(find.text('847 days'), findsOneWidget);
    expect(find.text('55474 XP'), findsOneWidget);
    expect(find.text('Sapphire'), findsOneWidget);
    expect(find.text('10 top finishes'), findsOneWidget);
    expect(find.text('FRIEND STREAKS'), findsOneWidget);
    expect(find.text('342'), findsOneWidget);
    expect(find.text('MONTHLY BADGES'), findsOneWidget);
    expect(find.text('ACHIEVEMENTS'), findsOneWidget);
    // Finish card is hidden once the avatar exists.
    expect(find.text('Finish your profile!'), findsNothing);
  });

  testWidgets('empty friend streaks invite and locked achievements render', (
    tester,
  ) async {
    await tester.pumpWidget(_pump(profileMockNew));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Invite a friend to a Friend Streak'),
      findsWidgets,
    );
    expect(find.bySemanticsLabel('October 2025, earned'), findsOneWidget);
    expect(find.text('NEW'), findsNothing);
  });

  testWidgets('share sheet opens with link and copy confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(_pump(profileMockNew));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Profile link'));
    await tester.pumpAndSettle();

    expect(find.textContaining('cocenglish.test/profile/me'), findsWidgets);
    // The sheet content can extend past the 600px test surface, so reveal
    // the action before tapping it.
    await tester.ensureVisible(find.text('COPY LINK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('COPY LINK'));
    // A single pump surfaces the confirmation: pumpAndSettle would wait out
    // the transient SnackBar dismissal before asserting.
    await tester.pump();
    expect(find.text('Profile link copied'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('avatar creation sheet shows start and maybe later', (
    tester,
  ) async {
    await tester.pumpWidget(_pump(profileMockNew));
    await tester.pumpAndSettle();

    await tester.tap(find.text('COMPLETE PROFILE'));
    await tester.pumpAndSettle();

    expect(find.text('Create your avatar!'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
    expect(find.text('MAYBE LATER'), findsOneWidget);
  });

  testWidgets('large text keeps actions reachable', (tester) async {
    await tester.pumpWidget(_pump(profileMockNew, textScale: 2));
    await tester.pumpAndSettle();

    expect(find.text('ADD FRIENDS'), findsOneWidget);
    expect(find.text('COMPLETE PROFILE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rich profile shows Max badge and family section', (
    tester,
  ) async {
    await tester.pumpWidget(_pump(profileMockRich));
    await tester.pumpAndSettle();

    expect(find.text('MAX'), findsOneWidget);
    expect(find.text('MAX FAMILY'), findsOneWidget);
    expect(find.text('MANAGE'), findsOneWidget);
    expect(find.bySemanticsLabel('Family member Mia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new profile hides Max badge and family section', (tester) async {
    await tester.pumpWidget(_pump(profileMockNew));
    await tester.pumpAndSettle();

    expect(find.text('MAX'), findsNothing);
    expect(find.text('MAX FAMILY'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
