import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/client/api_providers.dart';
import '../../../core/config/app_config.dart';
import 'api_account_repositories.dart';

/// Copy + catalog for Settings > Duolingo for Schools.
class SchoolsContent {
  const SchoolsContent({
    required this.heading,
    required this.body,
    required this.codeLabel,
    required this.codeHint,
    required this.joinLabel,
    required this.joinedPrefix,
    required this.leaveLabel,
  });
  final String heading, body, codeLabel, codeHint, joinLabel, joinedPrefix;
  final String leaveLabel;
}

/// A sign-in provider that can be linked under Settings > Social accounts.
class SocialAccount {
  const SocialAccount({required this.id, required this.name});
  final String id, name;
}

/// Copy + topics for Settings > Feedback.
class FeedbackContent {
  const FeedbackContent({
    required this.topicLabel,
    required this.topics,
    required this.messageLabel,
    required this.messageHint,
    required this.submitLabel,
    required this.thanksTitle,
    required this.thanksBody,
  });
  final String topicLabel, messageLabel, messageHint, submitLabel;
  final List<String> topics;
  final String thanksTitle, thanksBody;
}

/// Result of a classroom join attempt: exactly one of [classroom]/[error].
class ClassroomJoin {
  const ClassroomJoin.joined(String this.classroom) : error = null;
  const ClassroomJoin.failed(String this.error) : classroom = null;
  final String? classroom, error;
}

/// Settings boundary for Schools, Social accounts and Feedback. Swap the API
/// implementation by overriding [settingsRepositoryProvider].
abstract interface class SettingsContent {
  SchoolsContent get schools;
  List<SocialAccount> get socialAccounts;
  FeedbackContent get feedback;
}

abstract class SettingsRepository implements SettingsContent {
  Set<String> get connectedSocial;
  Future<ClassroomJoin> joinClassroom(String code);
  Future<void> setSocialConnected(String id, {required bool connected});
  Future<void> sendFeedback(String topic, String message);
}

class BundledSettingsContent implements SettingsContent {
  const BundledSettingsContent();

  @override
  SchoolsContent get schools => const SchoolsContent(
    heading: 'Join a classroom',
    body:
        'Enter the classroom code your teacher gave you to share your '
        'progress with them.',
    codeLabel: 'Classroom code',
    codeHint: 'e.g. ABC123',
    joinLabel: 'JOIN CLASSROOM',
    joinedPrefix: 'You joined',
    leaveLabel: 'LEAVE CLASSROOM',
  );

  @override
  List<SocialAccount> get socialAccounts => const [
    SocialAccount(id: 'facebook', name: 'Facebook'),
    SocialAccount(id: 'google', name: 'Google'),
  ];

  @override
  FeedbackContent get feedback => const FeedbackContent(
    topicLabel: 'What is your feedback about?',
    topics: ['Bug report', 'Lesson content', 'Suggestion'],
    messageLabel: 'Tell us more',
    messageHint: 'Describe what happened or what you would like to see',
    submitLabel: 'SUBMIT',
    thanksTitle: 'Thanks for your feedback!',
    thanksBody: 'Our team reads every message to make learning better.',
  );
}

class MockSettingsRepository extends BundledSettingsContent
    implements SettingsRepository {
  MockSettingsRepository({this.latency = const Duration(milliseconds: 60)});
  final Duration latency;
  final List<({String topic, String message})> sent = [];
  static const _classrooms = {'ABC123': 'Ms. Rivera’s English class'};
  final Set<String> _connected = {};
  @override
  Set<String> get connectedSocial => {..._connected};

  @override
  Future<ClassroomJoin> joinClassroom(String code) async {
    await Future<void>.delayed(latency);
    final normalized = code.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(normalized)) {
      return const ClassroomJoin.failed(
        'Classroom codes have 6 letters or numbers.',
      );
    }
    final name = _classrooms[normalized];
    return name == null
        ? const ClassroomJoin.failed(
            'We couldn’t find that classroom. Check the code with your teacher.',
          )
        : ClassroomJoin.joined(name);
  }

  @override
  Future<void> setSocialConnected(String id, {required bool connected}) async {
    await Future<void>.delayed(latency);
    connected ? _connected.add(id) : _connected.remove(id);
  }

  @override
  Future<void> sendFeedback(String topic, String message) async {
    await Future<void>.delayed(latency);
    sent.add((topic: topic, message: message));
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  if (ref.watch(appConfigProvider).isApi) {
    return ApiSettingsRepository(
      api: ref.watch(apiEndpointsProvider),
      content: const BundledSettingsContent(),
    );
  }
  return MockSettingsRepository();
});
