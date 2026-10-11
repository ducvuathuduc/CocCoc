/// Profile created at the end of the Duolingo-style signup flow.
class NewProfile {
  const NewProfile({
    required this.age,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
  });
  final int age;
  final String firstName, lastName, email, password;
  String get displayName => '$firstName $lastName'.trim();
}

/// Copy + timing for the delete-account flow, served by the repository so
/// the API can localise/override it later.
class DeleteAccountContent {
  const DeleteAccountContent({
    required this.title,
    required this.body,
    required this.subscriptionNotice,
    required this.instructionsLabel,
    required this.instructionsUrl,
    required this.actionLabel,
    required this.confirmTitle,
    required this.confirmQuestion,
    required this.cancelLabel,
    required this.doneTitle,
    required this.doneBody,
    required this.doneLabel,
    this.countdownSeconds = 5,
  });
  final String title, body, subscriptionNotice, instructionsLabel;
  final String instructionsUrl, actionLabel, confirmTitle, confirmQuestion;
  final String cancelLabel, doneTitle, doneBody, doneLabel;
  final int countdownSeconds;
}

/// Copy for the signup flow (titles, buttons, legal), served by the
/// repository so widgets carry no hardcoded text.
class SignupContent {
  const SignupContent({
    required this.promptMessage,
    required this.promptCreate,
    required this.promptLater,
    required this.titles,
    required this.agePlaceholder,
    required this.firstNamePlaceholder,
    required this.lastNamePlaceholder,
    required this.emailPlaceholder,
    required this.passwordPlaceholder,
    required this.nextLabel,
    required this.createLabel,
    required this.creatingLabel,
    required this.continueLabel,
    required this.legalPrefix,
    required this.termsLabel,
    required this.privacyLabel,
    required this.suggestedEmailLabel,
    required this.welcomeTemplate,
    required this.socialProviders,
  });
  final String promptMessage, promptCreate, promptLater;

  /// Titles per step: age, name, email, password. `{name}` is replaced.
  final List<String> titles;
  final String agePlaceholder, firstNamePlaceholder, lastNamePlaceholder;
  final String emailPlaceholder, passwordPlaceholder;
  final String nextLabel, createLabel, creatingLabel, continueLabel;
  final String legalPrefix, termsLabel, privacyLabel, suggestedEmailLabel;

  /// `{name}` is replaced with the first+last name.
  final String welcomeTemplate;
  final List<String> socialProviders;
}
