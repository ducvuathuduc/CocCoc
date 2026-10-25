import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../progress/application/preview_controller.dart';
import '../domain/account_models.dart';
import '../../../core/api/client/api_providers.dart';
import '../../../core/config/app_config.dart';
import '../../auth/application/auth_controller.dart';
import 'api_account_repositories.dart';

/// Account boundary for signup + deletion. Swap the API implementation by
/// overriding [accountRepositoryProvider].
abstract interface class AccountContent {
  SignupContent get signupContent;
  DeleteAccountContent get deleteContent;
}

abstract class AccountRepository implements AccountContent {
  /// Returns null on success, or a user-facing error message.
  Future<String?> createProfile(NewProfile profile);

  /// Returns null on success, or a user-facing error message.
  Future<String?> requestDeletion();
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  if (ref.watch(appConfigProvider).isApi) {
    // Watching identity retires callbacks from an account which has signed out.
    ref.watch(authControllerProvider.select((state) => state.user?.id));
    return ApiAccountRepository(
      api: ref.watch(apiEndpointsProvider),
      auth: ref.watch(authSessionRepositoryProvider),
      content: const BundledAccountContent(),
      createAccount: (email, password, name) => ref
          .read(authControllerProvider.notifier)
          .registerAccount(email, password, name),
      onDeletionAccepted: () {
        if (ref.mounted) {
          ref.read(realDeletionReceiptProvider.notifier).accepted();
        }
      },
    );
  }
  String? onRegister(String name, String email) => ref
      .read(previewControllerProvider.notifier)
      .saveProfile(name, email, register: true);
  void onDelete() =>
      ref.read(previewControllerProvider.notifier).requestDeletion();
  return MockAccountRepository(onRegister: onRegister, onDelete: onDelete);
});

final realDeletionReceiptProvider = NotifierProvider<RealDeletionReceipt, bool>(
  RealDeletionReceipt.new,
);

class RealDeletionReceipt extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(authControllerProvider.select((state) => state.user?.id));
    return false;
  }

  void accepted() => state = true;
}

/// Whether a deletion request is pending (drives the "Check your email"
/// receipt). Mock source: preview state.
final deletionRequestedProvider = Provider<bool>(
  (ref) => ref.watch(appConfigProvider).isApi
      ? ref.watch(realDeletionReceiptProvider)
      : ref.watch(previewControllerProvider).deletionRequested,
);

/// Immutable approved presentation content shared by preview and API builds.
class BundledAccountContent implements AccountContent {
  const BundledAccountContent();

  @override
  SignupContent get signupContent => const SignupContent(
    promptMessage: 'Don’t lose your progress! Let’s create a profile.',
    promptCreate: 'CREATE PROFILE',
    promptLater: 'LATER',
    titles: [
      'How old are you?',
      'What is your name?',
      'What is your email address, {name}?',
      'Create a password',
    ],
    agePlaceholder: 'Age',
    firstNamePlaceholder: 'First name',
    lastNamePlaceholder: 'Last name',
    emailPlaceholder: 'Email',
    passwordPlaceholder: 'Password',
    nextLabel: 'NEXT',
    createLabel: 'CREATE PROFILE',
    creatingLabel: 'CREATING PROFILE…',
    continueLabel: 'CONTINUE',
    legalPrefix: 'By signing in to Duolingo, you agree to our ',
    termsLabel: 'Terms',
    privacyLabel: 'Privacy Policy',
    suggestedEmailLabel: 'Suggested email',
    welcomeTemplate:
        'Welcome, {name}! Your profile has been successfully created.',
    socialProviders: ['google', 'facebook', 'apple'],
  );

  @override
  DeleteAccountContent get deleteContent => const DeleteAccountContent(
    title: 'Delete Account',
    body:
        'By proceeding, you will delete your Duolingo and Duolingo for '
        'Schools accounts and erase all of your personal data stored by '
        'Duolingo. You will lose your learning progress and achievements. '
        'Once completed this action cannot be undone. This deletion can take '
        'up to 30 days. You will have a 7 day grace period to abort the '
        'account deactivation process.',
    subscriptionNotice:
        'This action will NOT cancel an existing Duolingo subscription. '
        'Please cancel your subscription on the App Store or the Google Play '
        'Store. ',
    instructionsLabel: 'Instructions here.',
    instructionsUrl: 'https://support.duolingo.com',
    actionLabel: 'DELETE ACCOUNT',
    confirmTitle: 'Delete Account',
    confirmQuestion: 'Do you wish to delete your account?',
    cancelLabel: 'CANCEL',
    doneTitle: 'Check your email',
    doneBody:
        'You should receive an email soon to confirm your request. If '
        'you’ve already changed your mind, just ignore this email and carry '
        'on enjoying Duolingo!',
    doneLabel: 'DONE',
  );
}

class MockAccountRepository extends BundledAccountContent
    implements AccountRepository {
  MockAccountRepository({
    required this.onRegister,
    required this.onDelete,
    this.latency = const Duration(milliseconds: 60),
  });
  final String? Function(String name, String email) onRegister;
  final void Function() onDelete;
  final Duration latency;

  @override
  Future<String?> createProfile(NewProfile profile) async {
    await Future<void>.delayed(latency);
    return onRegister(profile.displayName, profile.email);
  }

  @override
  Future<String?> requestDeletion() async {
    await Future<void>.delayed(latency);
    onDelete();
    return null;
  }
}
