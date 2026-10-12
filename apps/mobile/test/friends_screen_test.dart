import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cocenglish/features/profile/presentation/friends_screen.dart';
import 'package:cocenglish/features/profile/data/friends_repository.dart';
import 'package:cocenglish/features/profile/application/friends_provider.dart';

void main() {
  testWidgets('FriendsScreen matches golden', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          friendsRepositoryProvider.overrideWithValue(
            const MockFriendsRepository.reference(),
          ),
        ],
        child: const MaterialApp(
          home: FriendsScreen(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );

    // wait for data
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(FriendsScreen),
      matchesGoldenFile('goldens/ui_master/sprint_friends_screen_430.png'),
    );
  });
}
