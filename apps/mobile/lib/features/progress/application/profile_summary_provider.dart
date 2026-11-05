import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../data/social_repository.dart';
import '../domain/profile_summary.dart';

const _sampleProfileSummaries = <String, ProfileSummary>{
  'Alex': ProfileSummary(
    userId: 'Alex',
    name: 'Alex',
    username: 'alex',
    joinedYear: 2025,
    xp: 120,
    followingCount: 8,
    streak: 7,
    league: 'Bronze',
    completedLessons: 32,
  ),
  'Maria': ProfileSummary(
    userId: 'Maria',
    name: 'Maria',
    username: 'maria',
    joinedYear: 2025,
    xp: 186,
    followingCount: 14,
    streak: 12,
    league: 'Silver',
    completedLessons: 46,
  ),
  'Lucas': ProfileSummary(
    userId: 'Lucas',
    name: 'Lucas',
    username: 'lucas',
    joinedYear: 2025,
    xp: 98,
    followingCount: 5,
    streak: 4,
    league: 'Bronze',
    completedLessons: 25,
  ),
  'Anna': ProfileSummary(
    userId: 'Anna',
    name: 'Anna',
    username: 'anna',
    joinedYear: 2025,
    xp: 214,
    followingCount: 21,
    streak: 18,
    league: 'Silver',
    completedLessons: 53,
  ),
  'Samira': ProfileSummary(
    userId: 'Samira',
    name: 'Samira',
    username: 'samira',
    joinedYear: 2025,
    xp: 144,
    followingCount: 11,
    streak: 9,
    league: 'Bronze',
    completedLessons: 37,
  ),
  'Sam Lee': ProfileSummary(
    userId: 'Sam Lee',
    name: 'Sam Lee',
    username: 'sam.lee',
    joinedYear: 2025,
    xp: 165,
    followingCount: 12,
    streak: 10,
    league: 'Silver',
    completedLessons: 41,
  ),
  'Noah': ProfileSummary(
    userId: 'Noah',
    name: 'Noah',
    username: 'noah',
    joinedYear: 2025,
    xp: 76,
    followingCount: 4,
    streak: 3,
    league: 'Bronze',
    completedLessons: 19,
  ),
  'Emma': ProfileSummary(
    userId: 'Emma',
    name: 'Emma',
    username: 'emma',
    joinedYear: 2025,
    xp: 201,
    followingCount: 18,
    streak: 15,
    league: 'Silver',
    completedLessons: 50,
  ),
  'James Smith': ProfileSummary(
    userId: 'James Smith',
    name: 'James Smith',
    username: 'james.smith',
    joinedYear: 2025,
    xp: 132,
    followingCount: 9,
    streak: 6,
    league: 'Bronze',
    completedLessons: 34,
  ),
};

/// Server public profile; mock mode and failures keep the authored fixture.
final publicProfileProvider = FutureProvider.family<SocialProfile?, String>((
  ref,
  userId,
) async {
  if (!ref.watch(appConfigProvider).isApi) return null;
  return ref.watch(socialRepositoryProvider).publicProfile(userId);
});

final profileSummaryProvider = Provider.family<ProfileSummary?, String>((
  ref,
  userId,
) {
  final fixture = _sampleProfileSummaries[userId];
  final profile = ref.watch(publicProfileProvider(userId)).asData?.value;
  if (profile == null) return fixture;
  return ProfileSummary(
    userId: profile.userId,
    name: profile.nickname,
    username: profile.nickname.toLowerCase().replaceAll(RegExp(r'\s+'), ''),
    joinedYear: fixture?.joinedYear ?? DateTime.now().year,
    xp: profile.studyXp,
    followingCount: fixture?.followingCount ?? 0,
    streak: profile.streak,
    league: fixture?.league ?? 'Bronze',
    completedLessons: fixture?.completedLessons ?? 0,
    followersCount: fixture?.followersCount ?? 0,
    topThreeFinishes: fixture?.topThreeFinishes ?? 0,
    leagueWeek: fixture?.leagueWeek ?? 1,
  );
});
