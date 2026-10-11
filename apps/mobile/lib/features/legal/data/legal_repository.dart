import '../domain/legal_models.dart';

/// Source of the in-app legal documents.
abstract class LegalRepository {
  LegalDocument document(LegalDocumentKind kind);
  List<OpenSourcePackage> packages();
}

/// Bundled copy. COC English is a student study project, so the documents
/// describe that honestly rather than imitating a commercial service.
class MockLegalRepository implements LegalRepository {
  const MockLegalRepository();

  static const _updated = 'Last updated: October 11, 2026';

  @override
  LegalDocument document(LegalDocumentKind kind) => switch (kind) {
    LegalDocumentKind.terms => _terms,
    LegalDocumentKind.privacy => _privacy,
    LegalDocumentKind.acknowledgements => LegalDocument(
      kind: kind,
      title: 'Acknowledgements',
      updated: _updated,
      intro:
          'COC English is built with open-source software. We are grateful '
          'to the authors and contributors of these projects.',
      sections: [
        for (final p in packages())
          LegalSection(
            heading: p.name,
            body: '${p.version} · ${p.license}\n${p.purpose}',
          ),
      ],
    ),
  };

  @override
  List<OpenSourcePackage> packages() => const [
    OpenSourcePackage(
      name: 'Flutter',
      version: 'SDK',
      license: 'BSD-3-Clause',
      purpose: 'UI toolkit used to build the whole app.',
    ),
    OpenSourcePackage(
      name: 'appwrite',
      version: '27.0.0',
      license: 'BSD-3-Clause',
      purpose: 'Backend client for accounts and sync.',
    ),
    OpenSourcePackage(
      name: 'cupertino_icons',
      version: '1.0.9',
      license: 'MIT',
      purpose: 'iOS-style icon font.',
    ),
    OpenSourcePackage(
      name: 'flutter_riverpod',
      version: '3.4.3',
      license: 'MIT',
      purpose: 'State management.',
    ),
    OpenSourcePackage(
      name: 'flutter_svg',
      version: '2.3.0',
      license: 'MIT',
      purpose: 'SVG rendering for illustrations.',
    ),
    OpenSourcePackage(
      name: 'go_router',
      version: '18.0.2',
      license: 'BSD-3-Clause',
      purpose: 'Navigation and deep links.',
    ),
    OpenSourcePackage(
      name: 'lottie',
      version: '3.6.1',
      license: 'MIT',
      purpose: 'Lottie animation playback.',
    ),
    OpenSourcePackage(
      name: 'qr_flutter',
      version: '4.1.0',
      license: 'BSD-3-Clause',
      purpose: 'QR codes for sharing profiles.',
    ),
    OpenSourcePackage(
      name: 'rive',
      version: '0.14.11',
      license: 'MIT',
      purpose: 'Interactive character animation.',
    ),
    OpenSourcePackage(
      name: 'shared_preferences',
      version: '2.5.5',
      license: 'BSD-3-Clause',
      purpose: 'On-device storage for settings.',
    ),
  ];

  static const _terms = LegalDocument(
    kind: LegalDocumentKind.terms,
    title: 'Terms',
    updated: _updated,
    intro:
        'Welcome to COC English. These Terms explain the rules for using the '
        'app. By using COC English, you agree to them.',
    sections: [
      LegalSection(
        heading: '1. About COC English',
        body:
            'COC English is a student study project that helps people practise '
            'English through short lessons, stories and speaking exercises. '
            'It is not a commercial product and is provided for learning and '
            'demonstration purposes.',
      ),
      LegalSection(
        heading: '2. Your account',
        body:
            'You are responsible for keeping your login details private and '
            'for activity on your account. Please give accurate information '
            'when you create a profile.',
      ),
      LegalSection(
        heading: '3. Acceptable use',
        body:
            'Do not misuse the app: no harassment of other learners, no '
            'attempts to break or overload the service, and no uploading of '
            'content you do not have the right to share.',
      ),
      LegalSection(
        heading: '4. Purchases and Super',
        body:
            'Gems, Super and other upgrades shown in the app are simulated '
            'for the study project. No real money is charged.',
      ),
      LegalSection(
        heading: '5. Learning content',
        body:
            'Lessons and exercises are provided as is. We try to keep them '
            'accurate, but we cannot guarantee that every answer is correct '
            'or that the app is always available.',
      ),
      LegalSection(
        heading: '6. Changes',
        body:
            'We may update these Terms as the project develops. The date at '
            'the top shows when they last changed.',
      ),
      LegalSection(
        heading: '7. Contact',
        body:
            'Questions about these Terms can be sent through Settings > '
            'Feedback.',
      ),
    ],
  );

  static const _privacy = LegalDocument(
    kind: LegalDocumentKind.privacy,
    title: 'Privacy Policy',
    updated: _updated,
    intro:
        'This Privacy Policy explains what information COC English collects, '
        'how it is used and the choices you have.',
    sections: [
      LegalSection(
        heading: 'Information we collect',
        body:
            'Profile details you enter (name, username, email, age), your '
            'learning progress (XP, streaks, completed lessons) and settings '
            'such as reminders and sound preferences.',
      ),
      LegalSection(
        heading: 'Speaking and microphone',
        body:
            'Speaking exercises use your microphone only while an exercise is '
            'open. Recordings are used to check your answer and are not kept.',
      ),
      LegalSection(
        heading: 'How we use information',
        body:
            'To run your account, save your progress, personalise lessons and '
            'improve the study project. We do not sell your information or '
            'show third-party ads.',
      ),
      LegalSection(
        heading: 'Where it is stored',
        body:
            'Settings are stored on your device. Account data is stored with '
            'our backend provider so it can sync between devices.',
      ),
      LegalSection(
        heading: 'Your choices',
        body:
            'You can make your profile private in Privacy settings, change '
            'notifications at any time, and delete your account from '
            'Settings > Profile, which erases your personal data.',
      ),
      LegalSection(
        heading: 'Children',
        body:
            'Learners under 13 should use COC English with a parent or '
            'teacher.',
      ),
      LegalSection(
        heading: 'Contact',
        body:
            'For privacy questions, send us a message through Settings > '
            'Feedback.',
      ),
    ],
  );
}
